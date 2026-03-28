//
//  Services.swift
//  swift-hydrogen
//

import ServiceLifecycle

// MARK: - AnyService

/// A type-erased ``Service`` wrapper.
///
/// Use this when you need to store or return a concrete `Service` conformance
/// whose generic type cannot be expressed directly — for example,
/// `GRPCServer<HTTP2ServerTransport.Posix>` as a `ServiceKey` value.
///
/// ```swift
/// let server = GRPCServer(...)
/// return (value: AnyService(server), service: AnyService(server))
/// ```
public struct AnyService: Service, Sendable {
    private let _run: @Sendable () async throws -> Void

    public init<S: Service & Sendable>(_ service: S) {
        _run = { try await service.run() }
    }

    public func run() async throws {
        try await _run()
    }
}

// MARK: - AnchorService

/// A no-op persistent service for values that have no independent lifecycle.
///
/// Use this when a `ConcreteServiceEntry` produces a value whose lifetime is
/// managed entirely by one of its dependencies (e.g. a data store backed by
/// a connection pool that is itself a registered service). The entry must
/// return *some* `Service`, so `AnchorService` fills that role by simply
/// sleeping until cancelled.
///
/// ```swift
/// ConcreteServiceEntry<DataStoreServiceKey>(...) { values, _, logger in
///     let store = MyDataStore(client: values.postgres!)
///     return (value: store, service: AnchorService())
/// }
/// ```
public struct AnchorService: Service, Sendable {
    public init() {}

    public func run() async throws {
        // Sleep for a very long but safe duration (Int32.max seconds ≈ 68 years).
        // Int.max overflows when converted to nanoseconds, so we use Int32.max.
        try await Task.sleep(for: .seconds(Int32.max))
    }
}
