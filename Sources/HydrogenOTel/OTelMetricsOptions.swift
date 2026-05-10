//
//  OTelMetricsOptions.swift
//  swift-hydrogen
//

#if HYDROGEN_OTEL

import ArgumentParser

/// Opinionated `ParsableArguments` for OTel metrics configuration.
public struct OTelMetricsOptions: ParsableArguments, Sendable {
    /// Enable OTel metrics. When `false`, the OTel bootstrap configures
    /// the metrics subsystem as disabled.
    @Flag(
        name: .customLong("metrics"),
        inversion: .prefixedNo,
        help: "Enable OTel metrics. Defaults to off."
    )
    public var enabled: Bool = false

    /// OTel collector endpoint for metrics (overrides traces endpoint when
    /// both are present).
    @Option(
        name: .customLong("otel-metrics-endpoint"),
        help: "OTel collector endpoint for metrics."
    )
    public var endpoint: String?

    public init() {}
}

#endif
