//
//  ServiceKey.swift
//  swift-hydrogen
//

/// Defines a key for accessing a value within ``ServiceValues``.
///
/// Conform to this protocol to define a new service or resource entry.
/// Each key has an associated `Value` type and a `defaultValue` fallback.
///
/// This follows the same pattern as SwiftUI's `EnvironmentKey`:
/// ```swift
/// struct PostgresServiceKey: ServiceKey {
///     static var defaultValue: PostgresClient? { nil }
/// }
/// ```
///
/// Keys are looked up by their metatype identity using `ObjectIdentifier`,
/// so each conforming type serves as a unique namespace for its value.
public protocol ServiceKey: Sendable {
    /// The type of value associated with this key.
    associatedtype Value: Sendable

    /// The default value returned when no value has been stored for this key.
    static var defaultValue: Value { get }
}
