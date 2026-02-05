//
//  ApplicationContext.swift
//  swift-hydrogen
//
//  Created by David Monagle on 27/1/2026.
//

import Configuration
import ServiceContextModule

@MainActor
public final class ApplicationContext {
    public let identifier: String
    public let config: ConfigReader
    public let registry: ApplicationRegistry

    private var cached: [Int: Any] = [:]

    public init(identifier: String, config: ConfigReader, registry: ApplicationRegistry) {
        self.identifier = identifier
        self.config = config
        self.registry = registry
    }

    public func resolve<R: ApplicationResource>(_ key: R.Type) throws -> R.Value {
        if let v = cached[key.id] as? R.Value { return v }

        guard registry.resource(key) != nil else {
            throw ApplicationRunner.Error.missingResource(R.name)
        }

        let built = try key.build(context: self)
        cached[key.id] = built
        return built
    }
}
