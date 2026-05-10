//
//  OTelTracingOptions.swift
//  swift-hydrogen
//

#if HYDROGEN_OTEL

import ArgumentParser

/// Opinionated `ParsableArguments` for OTel tracing configuration.
///
/// More OTel-specific than the vendor-neutral ``TracingOptions`` in core
/// Hydrogen — these flags map directly onto fields of
/// `OTel.Configuration.TracesConfiguration` and are consumed by
/// ``HydrogenOTel/makeBootstrap(serviceName:tracing:metrics:logs:)``.
///
/// Compose into a ``HydrogenCommand``:
///
/// ```swift
/// struct Serve: PersistentCommand {
///     typealias App = MyApp
///     @OptionGroup var tracing: OTelTracingOptions
///     var requiredServices: [any ServiceKey.Type] { [] }
///
///     func bootstrap(config: ConfigReader, environment: Environment) throws -> BootstrapPlan {
///         try HydrogenOTel.makeBootstrap(
///             serviceName: App.identifier,
///             tracing: tracing
///         )
///     }
/// }
/// ```
public struct OTelTracingOptions: ParsableArguments, Sendable {
    /// Enable OTel tracing. When `false`, the OTel bootstrap configures
    /// the traces subsystem as disabled and the global `withSpan` becomes
    /// a near-zero-cost passthrough.
    @Flag(
        name: .customLong("trace"),
        inversion: .prefixedNo,
        help: "Enable OTel tracing. Defaults to off."
    )
    public var enabled: Bool = false

    /// OTel collector endpoint (e.g. `localhost:4317` for OTLP/gRPC,
    /// `http://collector:4318` for OTLP/HTTP+Protobuf).
    @Option(
        name: .customLong("otel-endpoint"),
        help: "OTel collector endpoint for traces (e.g. localhost:4317)."
    )
    public var endpoint: String?

    /// Sampling rate, `[0.0, 1.0]`. `nil` keeps OTel's default (parent-based,
    /// `traceIDRatio` 1.0 at root).
    @Option(
        name: .customLong("trace-sample"),
        help: "Span sampling rate as a fraction in [0.0, 1.0]."
    )
    public var sampleRate: Double?

    public init() {}
}

#endif
