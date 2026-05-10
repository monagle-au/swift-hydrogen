//
//  ApplicationRunner.swift
//  swift-hydrogen
//

import ServiceLifecycle
import Logging
import Configuration

/// Internal orchestrator that resolves the service dependency graph, builds services,
/// and drives the ``ServiceGroup`` lifecycle.
///
/// You do not normally interact with `ApplicationRunner` directly. It is created
/// and used by the default ``HydrogenCommand/run()`` implementation.
struct ApplicationRunner: Sendable {
    /// The application identifier (used in logging and tracing).
    let identifier: String

    /// The registered service entries.
    let registry: ServiceRegistry

    /// Application configuration reader.
    let config: ConfigReader

    /// The active deployment environment.
    let environment: Environment

    /// Root logger for the application.
    let logger: Logger

    /// Resolves service dependencies, builds services, and runs the ``ServiceGroup``.
    ///
    /// - Parameters:
    ///   - requiredServices: The key types whose transitive dependencies should be
    ///     included in the service group. Pass the keys declared by the active command.
    ///   - mode: Whether the invocation is a persistent or task run.
    ///   - lifecycleServices: Pre-built services from the active ``BootstrapPlan``
    ///     (e.g. an OTel exporter). They start before user services so telemetry is
    ///     flowing as the application's own services come up. Not registered through
    ///     ``ServiceRegistry`` because they're not addressed by ``ServiceKey``.
    ///   - execute: An optional async closure to wrap in a ``CommandExecutionService``
    ///     (task mode only). Pass `nil` for persistent commands.
    func run(
        requiredServices: [any ServiceKey.Type],
        mode: ServiceLifecycleMode = .persistent,
        lifecycleServices: [LifecycleService] = [],
        execute: (@Sendable (ServiceValues) async throws -> Void)? = nil
    ) async throws {
        // Build an identifier → entry lookup map.
        var entryMap: [ObjectIdentifier: any ServiceEntry] = [:]
        for item in registry.entries {
            entryMap[item.key] = item.entry
        }

        // Build mode map for validation: key → mode
        var modeMap: [ObjectIdentifier: ServiceLifecycleMode] = [:]
        for item in registry.entries {
            modeMap[item.key] = item.entry.mode
        }

        // Convert required service types to ObjectIdentifiers (roots for topo sort).
        let roots = requiredServices.map { ObjectIdentifier($0) }

        // Topologically sort entries so dependencies come before dependents.
        let sorted = try topologicallySorted(roots: roots, entryMap: entryMap)

        // Validate: persistent services must not depend on task services.
        for item in sorted {
            guard item.entry.mode == .persistent else { continue }
            for depID in item.entry.dependencies {
                if modeMap[depID] == .task {
                    let depLabel = entryMap[depID]?.label ?? String(describing: depID)
                    throw ApplicationError.persistentDependsOnTask(
                        persistent: item.entry.label,
                        task: depLabel
                    )
                }
            }
        }

        // Build services in dependency order, accumulating ServiceValues.
        var values = ServiceValues()
        var serviceConfigs: [ServiceGroupConfiguration.ServiceConfiguration] = []

        // Lifecycle services from the bootstrap plan run ahead of user
        // services so exporters/shippers are draining as soon as the first
        // user service starts.
        for ls in lifecycleServices {
            var cfg = ServiceGroupConfiguration.ServiceConfiguration(service: ls.service)
            if ls.mode == .task {
                cfg.successTerminationBehavior = .gracefullyShutdownGroup
            }
            serviceConfigs.append(cfg)
        }

        for item in sorted {
            let service = try await withBuildSpan(label: item.entry.label) {
                try await item.entry.buildAndStore(from: &values, config: config, logger: logger)
            }

            var cfg = ServiceGroupConfiguration.ServiceConfiguration(service: service)
            if item.entry.mode == .task {
                cfg.successTerminationBehavior = .gracefullyShutdownGroup
            }
            serviceConfigs.append(cfg)
        }

        // If a task execute closure was provided, wrap it in a CommandExecutionService.
        if let execute {
            let capturedValues = values
            let executionService = CommandExecutionService {
                try await execute(capturedValues)
            }
            var cfg = ServiceGroupConfiguration.ServiceConfiguration(service: executionService)
            cfg.successTerminationBehavior = .gracefullyShutdownGroup
            serviceConfigs.append(cfg)
        }

        let groupConfig = ServiceGroupConfiguration(
            services: serviceConfigs,
            logger: logger
        )
        try await withRunSpan(label: identifier) {
            try await ServiceGroup(configuration: groupConfig).run()
        }
    }

    // MARK: - Topological Sort

    /// Performs a depth-first topological sort of the entries reachable from `roots`.
    ///
    /// - Parameters:
    ///   - roots: The `ObjectIdentifier`s of the root service keys (required services).
    ///   - entryMap: Mapping from key identifier to its registered ``ServiceEntry``.
    /// - Returns: Entries in dependency-first order (dependencies precede dependents).
    /// - Throws: ``ApplicationError/missingService(key:)`` if a dependency is not
    ///   registered, or ``ApplicationError/cyclicDependency(path:)`` if a cycle exists.
    private func topologicallySorted(
        roots: [ObjectIdentifier],
        entryMap: [ObjectIdentifier: any ServiceEntry]
    ) throws -> [(key: ObjectIdentifier, entry: any ServiceEntry)] {
        var visited = Set<ObjectIdentifier>()
        var inProgress = Set<ObjectIdentifier>()
        var result: [(key: ObjectIdentifier, entry: any ServiceEntry)] = []

        func visit(id: ObjectIdentifier, path: [String]) throws {
            if visited.contains(id) { return }

            guard let entry = entryMap[id] else {
                throw ApplicationError.missingService(key: path.last ?? String(describing: id))
            }

            if inProgress.contains(id) {
                throw ApplicationError.cyclicDependency(path: path + [entry.label])
            }

            inProgress.insert(id)

            for depID in entry.dependencies {
                guard let depEntry = entryMap[depID] else {
                    throw ApplicationError.missingService(key: entry.label)
                }
                try visit(id: depID, path: path + [entry.label, depEntry.label])
            }

            inProgress.remove(id)
            visited.insert(id)
            result.append((key: id, entry: entry))
        }

        for root in roots {
            try visit(id: root, path: [])
        }

        return result
    }
}
