//
//  ApplicationRegistry.swift
//  swift-hydrogen
//
//  Created by David Monagle on 27/1/2026.
//

import ServiceLifecycle

/// # ApplicationRegistry Concurrency Model
///
/// This framework uses a hybrid concurrency model optimized for simplified setup with Swift Service Lifecycle:
///
/// ## Setup Phase (Main Actor Isolated)
/// - `ApplicationRegistryBuilder`: Building the registry happens on the main actor
/// - `ApplicationContext.resolve()`: Resource resolution and building happens on the main actor
/// - Service `build()` methods: Service construction happens on the main actor
///
/// ## Execution Phase (Not Main Actor Isolated)
/// - Service `run()` methods: Services execute according to their own actor isolation
/// - Services can be actors, classes, or structs with custom isolation
/// - Resources must be Sendable if they'll be accessed from concurrent contexts
///
/// ## Design Benefits
/// - Simple, sequential setup phase on main actor (no complex coordination)
/// - Full flexibility for service execution (actors, tasks, etc.)
/// - Type-safe dependency resolution
/// - Works seamlessly with Swift Service Lifecycle

// MARK: - Base Protocol

/// A protocol for types that can be uniquely identified by their type itself
public protocol IdentifiableByType {
    /// A unique identifier for this type, used for storage and lookup
    static var id: Int { get }
}

extension IdentifiableByType {
    /// Default implementation that creates a stable hash from the type
    public static var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: Self.self))
        hasher.combine(ObjectIdentifier(Self.self))
        return hasher.finalize()
    }
}

// MARK: - Application Protocols

/// A protocol that defines a resource that can be registered with the application
/// Resources are singletons (database connections, loggers, etc.) that can be resolved from the ApplicationContext
///
/// ## Concurrency Model
/// Resource building happens on the MainActor during application setup. Once built, resources can be
/// accessed from services running on any actor/isolation domain, as long as the resource value itself is Sendable.
public protocol ApplicationResource: IdentifiableByType {
    /// The type of value this resource provides
    associatedtype Value
    
    /// A human-readable name for this resource (used in error messages)
    static var name: String { get }
    
    /// Build the resource from the application context
    @MainActor static func build(context: ApplicationContext) throws -> Value
}

/// A protocol that defines a service that can be registered with the application
///
/// ## Concurrency Model
/// Service building happens on the MainActor during application setup, but service execution
/// (the `run()` method) is not main-actor isolated. Services can adopt their own actor isolation
/// as needed (e.g., `actor MyService: ApplicationService` for actor-isolated services).
public protocol ApplicationService: Service, IdentifiableByType {
    /// The types of services this service depends on
    static var dependencies: [any ApplicationService.Type] { get }
    
    /// The termination behavior when the service completes successfully
    static var successTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? { get }
    
    /// The termination behavior when the service fails
    static var failureTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? { get }
    
    /// Build the service from the application context
    @MainActor static func build(context: ApplicationContext) throws -> Self
}

// Provide default implementations
extension ApplicationService {
    public static var dependencies: [any ApplicationService.Type] { [] }
    public static var successTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? { nil }
    public static var failureTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? { nil }
}

/// A protocol marker for services that should terminate the group on success (jobs)
public protocol ApplicationJob: ApplicationService {}

extension ApplicationJob {
    public static var successTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? {
        .gracefullyShutdownGroup
    }
}

// MARK: - Definition Types

/// A definition for a registered service
///
/// Note: This type uses `@unchecked Sendable` because:
/// - All construction happens on the MainActor
/// - The stored closure is only called from the MainActor
/// - The registry is immutable after creation
public struct ServiceDefinition: @unchecked Sendable {
    public typealias TerminationBehavior = ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior
    
    public let key: any ApplicationService.Type
    public let dependencies: [any ApplicationService.Type]
    public let build: @MainActor (ApplicationContext) throws -> any Service
    
    public var successTerminationBehavior: TerminationBehavior?
    public var failureTerminationBehavior: TerminationBehavior?
    
    nonisolated internal init<S: ApplicationService>(
        _ serviceType: S.Type,
        dependencies: [any ApplicationService.Type],
        build: @escaping @MainActor (ApplicationContext) throws -> S,
        successTerminationBehavior: TerminationBehavior? = nil,
        failureTerminationBehavior: TerminationBehavior? = nil
    ) {
        self.key = serviceType
        self.dependencies = dependencies
        self.build = { ctx in try build(ctx) }
        self.successTerminationBehavior = successTerminationBehavior
        self.failureTerminationBehavior = failureTerminationBehavior
    }
}

// MARK: - Registry

/// The application registry stores resource and service definitions
///
/// This registry is built on the MainActor and remains immutable after creation.
/// It uses `@unchecked Sendable` because:
/// - All mutations happen during the build phase on MainActor
/// - After building, the registry is read-only  
/// - All access to stored closures happens on the MainActor
public struct ApplicationRegistry: @unchecked Sendable {
    fileprivate var resources: [Int: any ApplicationResource.Type] = [:]
    fileprivate var services: [Int: ServiceDefinition] = [:]

    public func resource<R: ApplicationResource>(_ key: R.Type) -> R.Type? { 
        resources[key.id] as? R.Type
    }
    
    public func service<S: ApplicationService>(_ serviceType: S.Type) -> ServiceDefinition? { 
        services[serviceType.id] 
    }
}

// MARK: - Registry Builder

@MainActor
public struct ApplicationRegistryBuilder {
    private var registry = ApplicationRegistry()

    public init() {}
    
    /// Register a resource using the ApplicationResource protocol
    public mutating func register<R: ApplicationResource>(_ resource: R.Type) {
        registry.resources[resource.id] = resource
    }
    
    /// Register a service using the ApplicationService protocol
    public mutating func register<S: ApplicationService>(_ service: S.Type) {
        let definition = ServiceDefinition(
            service,
            dependencies: service.dependencies,
            build: service.build,
            successTerminationBehavior: service.successTerminationBehavior,
            failureTerminationBehavior: service.failureTerminationBehavior
        )
        registry.services[service.id] = definition
    }

    public func build() -> ApplicationRegistry { registry }
}
