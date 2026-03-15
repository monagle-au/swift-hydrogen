//
//  ServiceEntry.swift
//  swift-hydrogen
//

import ServiceLifecycle
import Logging
import Configuration

// MARK: - ServiceLifecycleMode

/// Describes how a service participates in the application lifecycle.
///
/// Use `.persistent` for long-running services (HTTP servers, background workers)
/// that should run until the application receives a termination signal.
///
/// Use `.task` for finite-duration services (migrations, one-off jobs) whose
/// completion should trigger a graceful shutdown of the whole service group.
public enum ServiceLifecycleMode: Sendable {
    /// The service runs until the application is externally terminated.
    ///
    /// When a persistent service finishes, the service group continues running.
    case persistent

    /// The service runs to completion and then signals the group to shut down.
    ///
    /// When a task service finishes successfully, the entire ``ServiceGroup``
    /// performs a graceful shutdown.
    case task
}

// MARK: - ServiceEntry Protocol

/// Describes a single entry in the ``ServiceRegistry``.
///
/// Each `ServiceEntry` knows how to build its service from a ``ServiceValues``
/// snapshot (populated with previously-built services), a ``ConfigReader``, and
/// a ``Logger``. After building, the entry stores the produced value back into
/// `ServiceValues` so downstream entries can consume it.
///
/// You generally interact with ``ConcreteServiceEntry`` rather than conforming
/// to this protocol directly.
public protocol ServiceEntry: Sendable {
    /// A human-readable label used in log output and tracing spans.
    var label: String { get }

    /// Whether this service is persistent or task-scoped.
    var mode: ServiceLifecycleMode { get }

    /// The keys of services this entry depends on, expressed as `ObjectIdentifier`
    /// values. The framework resolves these before building this entry.
    var dependencies: [ObjectIdentifier] { get }

    /// Builds the underlying service, stores its value in `values`, and returns
    /// the `Service` instance to be handed to a ``ServiceGroup``.
    ///
    /// - Parameters:
    ///   - values: The current snapshot of built service values. Updated in-place
    ///     with the value produced by this entry.
    ///   - config: Application configuration reader.
    ///   - logger: The application-level logger.
    /// - Returns: The built `Service` instance.
    /// - Throws: Any error from the underlying build closure, including
    ///   ``ApplicationError/missingConfiguration(key:service:)``.
    func buildAndStore(from values: inout ServiceValues, config: ConfigReader, logger: Logger) throws -> any Service
}

// MARK: - ConcreteServiceEntry

/// A concrete, generic ``ServiceEntry`` that wraps a typed build closure.
///
/// `ConcreteServiceEntry<K>` couples a ``ServiceKey`` type `K` with a closure
/// that constructs both the service value (stored as `K.Value` in
/// ``ServiceValues``) and the ``Service`` instance used for lifecycle management.
///
/// Typical usage:
///
/// ```swift
/// ConcreteServiceEntry<PostgresServiceKey>(
///     label: "postgres",
///     mode: .persistent,
///     dependencies: []
/// ) { values, config, logger in
///     let cfg = try PostgresClient.Configuration(config: config.scoped("postgres"))
///     let client = PostgresClient(configuration: cfg)
///     return (value: client, service: client)
/// }
/// ```
///
/// When the key's `Value` type itself conforms to `Service & Sendable`, you can
/// use the convenience initializer that derives both the value and the service
/// from the same instance.
public struct ConcreteServiceEntry<K: ServiceKey>: ServiceEntry {
    /// A human-readable label used in logging and tracing.
    public let label: String

    /// The lifecycle mode for this service.
    public let mode: ServiceLifecycleMode

    /// Dependencies expressed as `ObjectIdentifier` values derived from key types.
    public let dependencies: [ObjectIdentifier]

    private let buildClosure: @Sendable (ServiceValues, ConfigReader, Logger) throws -> (value: K.Value, service: any Service & Sendable)

    /// Creates a new entry with an explicit build closure.
    ///
    /// - Parameters:
    ///   - label: Human-readable name used in logs and tracing spans.
    ///   - mode: ``ServiceLifecycleMode`` governing lifecycle behaviour.
    ///   - dependencies: Key types that must be built before this entry.
    ///   - build: Closure that constructs the service value and the `Service` instance.
    public init(
        label: String,
        mode: ServiceLifecycleMode,
        dependencies: [any ServiceKey.Type] = [],
        build: @escaping @Sendable (ServiceValues, ConfigReader, Logger) throws -> (value: K.Value, service: any Service & Sendable)
    ) {
        self.label = label
        self.mode = mode
        self.dependencies = dependencies.map { ObjectIdentifier($0) }
        self.buildClosure = build
    }

    /// Builds the service, stores `K.Value` in `values`, and returns the `Service`.
    public func buildAndStore(from values: inout ServiceValues, config: ConfigReader, logger: Logger) throws -> any Service {
        let result = try buildClosure(values, config, logger)
        values[K.self] = result.value
        return result.service
    }
}

// MARK: Convenience init when K.Value is Service & Sendable

extension ConcreteServiceEntry where K.Value: Service & Sendable {
    /// Convenience initializer for cases where the key's value type is itself
    /// the `Service` — i.e., the built value is also the thing that is run.
    ///
    /// ```swift
    /// ConcreteServiceEntry<MyServiceKey>(
    ///     label: "my-service",
    ///     mode: .persistent
    /// ) { values, config, logger in
    ///     MyService(config: config)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - label: Human-readable label.
    ///   - mode: ``ServiceLifecycleMode`` governing lifecycle behaviour.
    ///   - dependencies: Key types that must be built before this entry.
    ///   - build: Closure that returns the service value (which is also the `Service`).
    public init(
        label: String,
        mode: ServiceLifecycleMode,
        dependencies: [any ServiceKey.Type] = [],
        build: @escaping @Sendable (ServiceValues, ConfigReader, Logger) throws -> K.Value
    ) {
        self.init(label: label, mode: mode, dependencies: dependencies) { values, config, logger in
            let value = try build(values, config, logger)
            return (value: value, service: value)
        }
    }
}
