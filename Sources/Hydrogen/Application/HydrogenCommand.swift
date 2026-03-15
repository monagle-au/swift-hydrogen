//
//  HydrogenCommand.swift
//  swift-hydrogen
//

import ArgumentParser
import Configuration
import Logging

// MARK: - UncheckedSendableBox

/// A minimal wrapper that bridges a non-`Sendable` value into a `@Sendable` closure context.
///
/// This is used internally to capture `self` (a `HydrogenCommand`, which is not required
/// to be `Sendable`) inside the `@Sendable` execute closure passed to ``ApplicationRunner``.
/// Usage is safe because the command's `execute(with:)` call happens sequentially on a single
/// task and does not escape to other concurrency domains.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}

// MARK: - HydrogenCommand

/// A command within a Hydrogen application.
///
/// Commands declare which services they need via `requiredServices`. The framework
/// handles dependency resolution, service building, and lifecycle management
/// automatically in the default `run()` implementation.
///
/// For persistent commands (e.g. an HTTP server), conform to ``PersistentCommand``
/// which does not require an `execute(with:)` — the services simply run until
/// the process receives a termination signal.
///
/// For task commands (e.g. a database migration), conform to ``TaskCommand``
/// which requires `execute(with:)` — when the closure returns, the service group
/// is gracefully shut down.
///
/// ```swift
/// struct Migrate: TaskCommand {
///     typealias App = MyApp
///     static let configuration = CommandConfiguration(abstract: "Run migrations")
///
///     var requiredServices: [any ServiceKey.Type] { [PostgresServiceKey.self] }
///
///     func execute(with services: ServiceValues) async throws {
///         // migration logic using services.postgres
///     }
/// }
/// ```
public protocol HydrogenCommand: AsyncParsableCommand {
    /// The application type that owns this command and supplies service registrations.
    associatedtype App: HydrogenApplication

    /// The service keys whose transitive dependencies will be started before the
    /// command runs.
    var requiredServices: [any ServiceKey.Type] { get }

    /// Called after all required services have been built and started.
    ///
    /// The default implementation is a no-op, suitable for ``PersistentCommand``
    /// conformances where the services themselves constitute the entire workload.
    ///
    /// Override this in ``TaskCommand`` conformances to perform work and then
    /// allow the service group to shut down.
    ///
    /// - Parameter services: A snapshot of the built service values.
    func execute(with services: ServiceValues) async throws
}

extension HydrogenCommand {
    /// Default no-op execute — appropriate for persistent commands.
    public func execute(with services: ServiceValues) async throws {}

    /// Default `run()` implementation wired into ArgumentParser.
    ///
    /// This implementation:
    /// 1. Reads the active ``Environment`` from the current ``ServiceContext``,
    ///    falling back to `.development` if not set.
    /// 2. Constructs a ``ConfigReader`` backed by ``EnvironmentVariablesProvider``.
    /// 3. Calls `App.configure(_:)` to populate a ``ServiceRegistry``.
    /// 4. Creates an ``ApplicationRunner`` and invokes ``ApplicationRunner/run(requiredServices:mode:execute:)``.
    ///
    /// The lifecycle mode is inferred from whether `self` conforms to ``TaskCommand``.
    public func run() async throws {
        let environment = ServiceContext.active.environment ?? .development
        let config = ConfigReader(provider: EnvironmentVariablesProvider())
        var registry = ServiceRegistry()
        App.configure(&registry)

        let logger = Logger(label: App.identifier)

        let runner = ApplicationRunner(
            identifier: App.identifier,
            registry: registry,
            config: config,
            environment: environment,
            logger: logger
        )

        let requiredServicesCopy = requiredServices

        if self is any TaskCommand {
            // Task mode: wrap execute in a CommandExecutionService.
            // We cannot capture `self` (non-Sendable existential) in a @Sendable closure,
            // so we resolve the execute closure into a concrete @Sendable wrapper.
            try await _runAsTask(runner: runner, requiredServices: requiredServicesCopy)
        } else {
            // Persistent mode: services run until externally terminated.
            let noExecute: (@Sendable (ServiceValues) async throws -> Void)? = nil
            try await runner.run(
                requiredServices: requiredServicesCopy,
                mode: ServiceLifecycleMode.persistent,
                execute: noExecute
            )
        }
    }

    /// Internal helper that runs this command in task mode.
    ///
    /// Separated to allow a concrete generic context where `Self` can be
    /// constrained to `Sendable` in the future if needed.
    private func _runAsTask(
        runner: ApplicationRunner,
        requiredServices: [any ServiceKey.Type]
    ) async throws {
        // Build a Sendable-compatible capture by boxing the execute work.
        // Since HydrogenCommand does not require Sendable, we use @unchecked Sendable
        // via a box type to safely bridge to the @Sendable closure requirement.
        // Service building is sequential and the execute work happens after setup.
        let box = UncheckedSendableBox(value: self)
        let executeClosure: @Sendable (ServiceValues) async throws -> Void = { services in
            try await box.value.execute(with: services)
        }
        try await runner.run(
            requiredServices: requiredServices,
            mode: ServiceLifecycleMode.task,
            execute: executeClosure
        )
    }
}

// MARK: - PersistentCommand

/// A persistent command whose services run until the application receives a
/// termination signal.
///
/// Use this for long-running workloads such as HTTP servers or message consumers.
/// You do not need to implement `execute(with:)` — the default no-op is used.
///
/// ```swift
/// struct Serve: PersistentCommand {
///     typealias App = MyApp
///     static let configuration = CommandConfiguration(abstract: "Start the server")
///     var requiredServices: [any ServiceKey.Type] { [HTTPServerServiceKey.self] }
/// }
/// ```
public protocol PersistentCommand: HydrogenCommand {}

// MARK: - TaskCommand

/// A task command that performs a finite unit of work and then shuts down.
///
/// Implement `execute(with:)` to run your task logic. When the closure returns
/// (or throws), the framework gracefully shuts down all running services.
///
/// ```swift
/// struct Migrate: TaskCommand {
///     typealias App = MyApp
///     static let configuration = CommandConfiguration(abstract: "Run migrations")
///     var requiredServices: [any ServiceKey.Type] { [PostgresServiceKey.self] }
///
///     func execute(with services: ServiceValues) async throws {
///         try await PostgresMigrator(client: services.postgres!).migrate()
///     }
/// }
/// ```
public protocol TaskCommand: HydrogenCommand {
    /// Performs the command's task work.
    ///
    /// Called after all required services have been started. When this method
    /// returns or throws, the service group is gracefully shut down.
    ///
    /// - Parameter services: A snapshot of the built service values.
    func execute(with services: ServiceValues) async throws
}
