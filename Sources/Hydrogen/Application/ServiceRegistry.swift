//
//  ServiceRegistry.swift
//  swift-hydrogen
//

/// A mutable collection of ``ServiceEntry`` values, keyed by their ``ServiceKey`` type.
///
/// `ServiceRegistry` is populated during application startup via
/// ``HydrogenApplication/configure(_:)`` and then handed to ``ApplicationRunner``
/// for service resolution and lifecycle orchestration.
///
/// Entries are stored in registration order, which is preserved when building
/// the dependency graph during topological sort.
///
/// ```swift
/// static func configure(_ services: inout ServiceRegistry) {
///     services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
///     services.register(MyWorkerServiceKey.self, entry: myWorkerServiceEntry())
/// }
/// ```
public struct ServiceRegistry: Sendable {
    /// Internal storage: ordered list of (key identifier, entry) pairs.
    internal var entries: [(key: ObjectIdentifier, entry: any ServiceEntry)] = []

    /// Creates an empty registry.
    public init() {}

    /// Registers a ``ServiceEntry`` under the given key type.
    ///
    /// If the same key type is registered more than once, the later registration
    /// replaces the earlier one.
    ///
    /// - Parameters:
    ///   - keyType: The ``ServiceKey`` type used to identify this entry.
    ///   - entry: The entry describing how to build and configure the service.
    public mutating func register<K: ServiceKey>(_ keyType: K.Type, entry: any ServiceEntry) {
        let id = ObjectIdentifier(keyType)
        // Replace existing entry for the same key if present.
        if let index = entries.firstIndex(where: { $0.key == id }) {
            entries[index] = (key: id, entry: entry)
        } else {
            entries.append((key: id, entry: entry))
        }
    }
}
