//
//  ServiceValues.swift
//  swift-hydrogen
//

/// A value-type container for resolved service instances, keyed by ``ServiceKey`` types.
///
/// `ServiceValues` is the SwiftUI `EnvironmentValues` analog for Hydrogen services.
/// It stores values by the `ObjectIdentifier` of their key type, providing type-safe
/// subscript access.
///
/// Commands receive a populated `ServiceValues` instance that they can use to
/// access the services they declared as required:
///
/// ```swift
/// func execute(with services: ServiceValues) async throws {
///     guard let postgres = services[PostgresServiceKey.self] else {
///         throw MyError.missingDatabase
///     }
///     // use postgres …
/// }
/// ```
///
/// You can also extend `ServiceValues` with named accessors for ergonomic access:
///
/// ```swift
/// extension ServiceValues {
///     public var postgres: PostgresClient? {
///         get { self[PostgresServiceKey.self] }
///         set { self[PostgresServiceKey.self] = newValue }
///     }
/// }
/// ```
public struct ServiceValues: Sendable {
    private var storage: [ObjectIdentifier: any Sendable] = [:]

    /// Creates an empty `ServiceValues` container.
    public init() {}

    /// Accesses the value stored for the given key type.
    ///
    /// Reading returns the stored value if present, otherwise ``ServiceKey/defaultValue``.
    /// Writing replaces the stored value for that key.
    ///
    /// - Parameter key: The key type to look up.
    public subscript<K: ServiceKey>(key: K.Type) -> K.Value {
        get { (storage[ObjectIdentifier(K.self)] as? K.Value) ?? K.defaultValue }
        set { storage[ObjectIdentifier(K.self)] = newValue }
    }
}
