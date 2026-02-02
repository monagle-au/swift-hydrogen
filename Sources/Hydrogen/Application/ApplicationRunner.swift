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

    public func run(_ roots: [ApplicationServiceKey]) async throws {
        let configs: [ServiceGroupConfiguration.ServiceConfiguration] = try await MainActor.run {
            let ordered = try topoSortedClosure(for: roots)
            return try ordered.map { key in
                guard let def = context.registry.service(key) else {
                    throw Error.missingService(key.rawValue)
                }

                let svc = try def.build(context)

                var cfg = ServiceGroupConfiguration.ServiceConfiguration(service: svc)
                if let s = def.successTerminationBehavior { cfg.successTerminationBehavior = s }
                if let f = def.failureTerminationBehavior { cfg.failureTerminationBehavior = f }
                return cfg
            }
        }
        // TODO: Pull this from the logger resource
        let logger = Logger(label: "service-lifecycle")

        try await ServiceGroup(configuration: .init(services: configs, logger: logger)).run()
    }

    private func topoSortedClosure(for roots: [ApplicationServiceKey]) throws -> [ApplicationServiceKey] {
        var visited = Set<ApplicationServiceKey>()
        var temp = Set<ApplicationServiceKey>()
        var result: [ApplicationServiceKey] = []

        func visit(_ key: ApplicationServiceKey, path: [ApplicationServiceKey]) throws {
            if visited.contains(key) { return }
            if temp.contains(key) {
                throw Error.cyclicDependency((path + [key]))
            }
            temp.insert(key)

            guard let def = context.registry.service(key) else {
                throw Error.missingService(key.rawValue)
            }
            for dep in def.dependencies { try visit(dep, path: path + [key]) }

            temp.remove(key)
            visited.insert(key)
            result.append(key)
        }

        for r in roots { try visit(r, path: []) }
        return result
    }
}
extension ApplicationRunner {
    public enum Error: Swift.Error, CustomStringConvertible {
        case missingService(String)
        case missingResource(String)
        case cyclicDependency([ApplicationServiceKey])
        case resourceTypeMismatch(String)

        public var description: String {
            switch self {
            case .missingService(let k): "Missing service registration: \(k)"
            case .missingResource(let k): "Missing resource registration: \(k)"
            case .cyclicDependency(let path): "Cyclic dependency detected: \(path.map(\.rawValue).joined(separator: " -> "))"
            case .resourceTypeMismatch(let resource): "Mismatched value type for resource: \(resource)"
            }
        }
    }
}

