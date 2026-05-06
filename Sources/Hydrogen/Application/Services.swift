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
///
/// The `init(onShutdown:)` overload lets the entry attach an async cleanup
/// hook for resources it actually owns (e.g. an `HTTPClient` whose
/// `shutdown()` releases NIO event-loop threads). The hook runs after the
/// surrounding task is cancelled and before the cancellation re-raises:
///
/// ```swift
/// ConcreteServiceEntry<MyClientServiceKey>(...) { _, _, _ in
///     let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
///     let client = MyClient(httpClient: httpClient)
///     return (value: client, service: AnchorService {
///         try? await httpClient.shutdown()
///     })
/// }
/// ```
public struct AnchorService: Service, Sendable {

    private let onShutdown: (@Sendable () async -> Void)?

    /// Pure-anchor variant — sleeps until cancelled, no cleanup.
    public init() {
        self.onShutdown = nil
    }

    /// Cleanup variant — sleeps until cancelled, then runs `onShutdown`
    /// before re-raising the cancellation. Use when the service owns a
    /// resource that needs async teardown (HTTP client connection pool,
    /// long-lived gRPC channel, etc.).
    ///
    /// `onShutdown` is `async` (not `throws`) — wrap any throwing
    /// teardown call in `try?` because there's nothing the lifecycle
    /// library can do with a thrown error during shutdown.
    public init(onShutdown: @escaping @Sendable () async -> Void) {
        self.onShutdown = onShutdown
    }

    public func run() async throws {
        do {
            // Sleep for a very long but safe duration (Int32.max seconds ≈ 68 years).
            // Int.max overflows when converted to nanoseconds, so we use Int32.max.
            try await Task.sleep(for: .seconds(Int32.max))
        } catch {
            // SIGTERM → ServiceGroup cancels → Task.sleep throws.
            // Run the cleanup hook (if any) before re-raising so the
            // lifecycle library still treats this as a graceful
            // termination via CancellationError.
            await onShutdown?()
            throw error
        }
    }
}
