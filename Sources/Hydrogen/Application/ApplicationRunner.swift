//
//  ApplicationRunner.swift
//  swift-hydrogen
//
//  Created by David Monagle on 27/1/2026.
//

import ServiceLifecycle

@MainActor public struct ApplicationRunner {
    public let context: ApplicationContext

    public init(context: ApplicationContext) {
        self.context = context
    }
    
    /// Bootstrap an ApplicationRunner with resources and services
    public static func bootstrap(
        identifier: String,
        config: ConfigReader,
        resources: [any ApplicationResource.Type] = [],
        services: [any ApplicationService.Type] = []
    ) -> ApplicationRunner {
        var builder = ApplicationRegistryBuilder()
        
        // Register all resources
        for resource in resources {
            builder.register(resource)
        }
        
        // Register all services
        for service in services {
            builder.register(service)
        }
        
        let registry = builder.build()
        let context = ApplicationContext(identifier: identifier, config: config, registry: registry)
        return ApplicationRunner(context: context)
    }

    public func run(_ roots: any ApplicationService.Type ...) async throws {
        try await self.run(roots)
    }
    
    public func run(_ roots: [any ApplicationService.Type]) async throws {
        let configs: [ServiceGroupConfiguration.ServiceConfiguration] = try await MainActor.run {
            let ordered = try topoSortedClosure(for: roots)
            return try ordered.map { serviceType in
                guard let def = context.registry.service(serviceType) else {
                    throw Error.missingService(String(describing: serviceType))
                }

                let svc = try def.build(context)

                var cfg = ServiceGroupConfiguration.ServiceConfiguration(service: svc)
                if let s = def.successTerminationBehavior { cfg.successTerminationBehavior = s }
                if let f = def.failureTerminationBehavior { cfg.failureTerminationBehavior = f }
                return cfg
            }
        }
        
        let logger = Logger(label: "service-lifecycle")
        try await ServiceGroup(configuration: .init(services: configs, logger: logger)).run()
    }

    private func topoSortedClosure(for roots: [any ApplicationService.Type]) throws -> [any ApplicationService.Type] {
        var visited = Set<Int>()
        var temp = Set<Int>()
        var result: [any ApplicationService.Type] = []

        func visit(_ serviceType: any ApplicationService.Type, path: [any ApplicationService.Type]) throws {
            let id = serviceType.id
            if visited.contains(id) { return }
            if temp.contains(id) {
                throw Error.cyclicDependency((path + [serviceType]).map { String(describing: $0) })
            }
            temp.insert(id)

            guard let def = context.registry.service(serviceType) else {
                throw Error.missingService(String(describing: serviceType))
            }
            for dep in def.dependencies { 
                try visit(dep, path: path + [serviceType]) 
            }

            temp.remove(id)
            visited.insert(id)
            result.append(serviceType)
        }

        for r in roots { try visit(r, path: []) }
        return result
    }
}
extension ApplicationRunner {
    public enum Error: Swift.Error, CustomStringConvertible {
        case missingService(String)
        case missingResource(String)
        case cyclicDependency([String])
        case resourceTypeMismatch(String)

        public var description: String {
            switch self {
            case .missingService(let k): "Missing service registration: \(k)"
            case .missingResource(let k): "Missing resource registration: \(k)"
            case .cyclicDependency(let path): "Cyclic dependency detected: \(path.joined(separator: " -> "))"
            case .resourceTypeMismatch(let resource): "Mismatched value type for resource: \(resource)"
            }
        }
    }
}

