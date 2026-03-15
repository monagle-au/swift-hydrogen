//
//  ApplicationRunner+Observability.swift
//  swift-hydrogen
//

import Tracing
import Metrics

extension ApplicationRunner {
    /// Executes a synchronous build closure, recording a metric on success.
    ///
    /// A `Counter` named `hydrogen.service.builds` is incremented after a
    /// successful build, labelled with the service name.
    ///
    /// - Parameters:
    ///   - label: The service label used in the metric dimension.
    ///   - body: The synchronous build closure.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    func withBuildSpan<T>(label: String, body: () throws -> T) throws -> T {
        let value = try body()
        Counter(label: "hydrogen.service.builds", dimensions: [("service", label)]).increment()
        return value
    }

    /// Executes an async run closure within a distributed tracing span.
    ///
    /// Opens a span named `hydrogen.application.run` and attaches the application
    /// identifier as a span attribute before awaiting the body.
    ///
    /// - Parameters:
    ///   - label: The application identifier attached to the span as an attribute.
    ///   - body: The async closure to run within the span.
    /// - Throws: Any error thrown by `body`.
    func withRunSpan(label: String, body: () async throws -> Void) async throws {
        try await withSpan("hydrogen.application.run") { span in
            span.attributes["hydrogen.identifier"] = label
            try await body()
        }
    }
}
