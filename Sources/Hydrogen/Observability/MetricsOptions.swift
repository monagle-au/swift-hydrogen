//
//  MetricsOptions.swift
//  swift-hydrogen
//

import ArgumentParser

/// Reusable `ParsableArguments` for command-line metrics configuration.
///
/// Vendor-neutral: it carries values only. The app's
/// ``HydrogenCommand/bootstrap(config:environment:)`` consumes them to
/// construct an actual `MetricsFactory` and assigns it to
/// ``BootstrapPlan/metricsFactory``.
public struct MetricsOptions: ParsableArguments, Sendable {
    /// Master enable/disable for metrics. When `false`, the bootstrap
    /// leaves the global metrics system on its no-op default.
    @Flag(
        name: .customLong("metrics"),
        inversion: .prefixedNo,
        help: "Enable metrics export. Defaults to off."
    )
    public var enabled: Bool = false

    /// Metrics-collector endpoint. Format depends on the exporter the
    /// app builds (OTLP/Prometheus pushgateway/StatsD/…).
    @Option(
        name: .customLong("metrics-endpoint"),
        help: "Metrics collector endpoint."
    )
    public var endpoint: String?

    /// Optional explicit interval (seconds) between metrics pushes. `nil`
    /// defers to the exporter's default.
    @Option(
        name: .customLong("metrics-interval"),
        help: "Interval (seconds) between metrics pushes."
    )
    public var intervalSeconds: Int?

    public init() {}
}
