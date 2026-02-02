//
//  ApplicationRegistry.swift
//  swift-hydrogen
//
//  Created by David Monagle on 27/1/2026.
//

import ServiceLifecycle

public struct ResourceDefinition {
    public let key: any ApplicationResourceKey.Type
    public let build: @MainActor (ApplicationContext) throws -> Any

    public init<K: ApplicationResourceKey>(
        _ key: K.Type,
        build: @escaping @MainActor (ApplicationContext) throws -> K.Value
    ) {
        self.key = key
        self.build = { ctx in try build(ctx) }
    }
}

public struct ServiceDefinition {
    public typealias TerminationBehavior = ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior
    
    public let key: ApplicationServiceKey
    public let dependencies: [ApplicationServiceKey]
    public let build: @MainActor (ApplicationContext) throws -> any Service
    
    public var successTerminationBehavior: TerminationBehavior?
    public var failureTerminationBehavior: TerminationBehavior?
    
    internal init(key: ApplicationServiceKey, dependencies: [ApplicationServiceKey], build: @escaping @MainActor @Sendable (ApplicationContext) throws -> any Service, successTerminationBehavior: ServiceDefinition.TerminationBehavior? = nil, failureTerminationBehavior: ServiceDefinition.TerminationBehavior? = nil) {
        self.key = key
        self.dependencies = dependencies
        self.build = build
        self.successTerminationBehavior = successTerminationBehavior
        self.failureTerminationBehavior = failureTerminationBehavior
    }
    
    public static func service(key: ApplicationServiceKey, dependencies: [ApplicationServiceKey] = [], build: @escaping @MainActor @Sendable (ApplicationContext) throws -> any Service) -> Self {
        self.init(key: key, dependencies: dependencies, build: build)
    }
    
    public static func job(key: ApplicationServiceKey, dependencies: [ApplicationServiceKey] = [], build: @escaping @MainActor @Sendable (ApplicationContext) throws -> any Service) -> Self {
        self.init(key: key, dependencies: dependencies, build: build, successTerminationBehavior: .gracefullyShutdownGroup)
    }
}

public struct ApplicationRegistry {
    fileprivate var resources: [Int: ResourceDefinition] = [:]
    fileprivate var services: [ApplicationServiceKey: ServiceDefinition] = [:]

    public func resource(_ key: any ApplicationResourceKey.Type) -> ResourceDefinition? { resources[key.id] }
    public func service(_ key: ApplicationServiceKey) -> ServiceDefinition? { services[key] }
}

@MainActor
public struct ApplicationRegistryBuilder {
    private var registry = ApplicationRegistry()

    public init() {}

    public mutating func register<K: ApplicationResourceKey>(
        _ key: K.Type,
        build: @escaping @MainActor (ApplicationContext) throws -> K.Value
    ) {
        registry.resources[key.id] = ResourceDefinition(key, build: build)
    }

    public mutating func register(service: ServiceDefinition) {
        registry.services[service.key] = service
    }

    public func build() -> ApplicationRegistry { registry }
}
