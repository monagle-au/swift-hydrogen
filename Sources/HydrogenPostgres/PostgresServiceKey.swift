//
//  PostgresServiceKey.swift
//  swift-hydrogen
//

import Hydrogen
import PostgresNIO

// MARK: - PostgresServiceKey

/// The ``ServiceKey`` for accessing a ``PostgresClient`` from ``ServiceValues``.
///
/// Register a Postgres service entry using ``postgresServiceEntry()`` and access
/// the built client via ``ServiceValues/postgres``:
///
/// ```swift
/// static func configure(_ services: inout ServiceRegistry) {
///     services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
/// }
/// ```
public struct PostgresServiceKey: ServiceKey {
    /// The default value — `nil` when no Postgres client has been registered.
    public static var defaultValue: PostgresClient? { nil }
}

// MARK: - ServiceValues Extension

extension ServiceValues {
    /// The registered ``PostgresClient``, if one has been configured.
    ///
    /// Returns `nil` unless a ``PostgresServiceKey`` entry has been registered
    /// and built.
    public var postgres: PostgresClient? {
        get { self[PostgresServiceKey.self] }
        set { self[PostgresServiceKey.self] = newValue }
    }
}

// MARK: - Factory

/// Creates a ``ConcreteServiceEntry`` that builds a ``PostgresClient`` from
/// application configuration.
///
/// The entry reads connection parameters from the `postgres` configuration scope.
/// Required keys (depending on connection mode):
/// - `postgres.host` (default: `"localhost"`)
/// - `postgres.port` (default: `5432`)
/// - `postgres.username` (default: `"postgres"`)
/// - `postgres.password`
/// - `postgres.database`
/// - `postgres.unixSocketPath` (optional, mutually exclusive with host/port)
///
/// TLS options are read from `postgres.tls.*`.
///
/// ```swift
/// services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
/// ```
///
/// - Returns: A `ConcreteServiceEntry<PostgresServiceKey>` configured as a
///   persistent service.
public func postgresServiceEntry() -> ConcreteServiceEntry<PostgresServiceKey> {
    ConcreteServiceEntry<PostgresServiceKey>(
        label: "postgres",
        mode: .persistent
    ) { _, config, logger in
        let pgConfig = PostgresClient.Configuration(config: config.scoped(to: "postgres"))
        let client = PostgresClient(configuration: pgConfig, backgroundLogger: logger)
        return (value: client, service: client)
    }
}
