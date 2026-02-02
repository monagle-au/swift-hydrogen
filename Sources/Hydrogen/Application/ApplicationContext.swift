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

    public func resolve<K: ApplicationResourceKey>(_ key: K.Type) throws -> K.Value {
        if let v = cached[key.id] as? K.Value { return v }

        guard let def = registry.resource(key) else {
            throw ApplicationRunner.Error.missingResource(K.name)
        }

        let built = try def.build(self)
        guard let typed = built as? K.Value else {
            throw ApplicationRunner.Error.resourceTypeMismatch(K.name)
        }

        cached[key.id] = typed
        return typed
    }
}
