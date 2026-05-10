//
//  TracingOptions.swift
//  swift-hydrogen
//

import ArgumentParser

/// Reusable `ParsableArguments` for command-line tracing configuration.
///
/// Vendor-neutral: it carries values only. The app's
/// ``HydrogenCommand/bootstrap(config:environment:)`` consumes them to
/// construct an actual `Instrument` (e.g. via the `HydrogenOTel` target
/// when the `OTel` package trait is enabled, or via a hand-rolled tracer)
/// and assigns it to ``BootstrapPlan/instrument``.
///
/// ```swift
/// struct Serve: PersistentCommand {
///     typealias App = MyApp
///     @OptionGroup var tracing: TracingOptions
///     var requiredServices: [any ServiceKey.Type] { [] }
///
///     func bootstrap(config: ConfigReader, environment: Environment) -> BootstrapPlan {
///         var plan = BootstrapPlan()
///         if tracing.enabled {
///             // App-side: build a tracer using tracing.endpoint, tracing.serviceName, etc.
///             let tracer = MyTracer(endpoint: tracing.endpoint, serviceName: tracing.serviceName ?? App.identifier)
///             plan.instrument = tracer
///         }
///         return plan
///     }
/// }
/// ```
public struct TracingOptions: ParsableArguments, Sendable {
    /// Master enable/disable for tracing. When `false`, the bootstrap leaves
    /// the global instrumentation system on its `NoOpInstrument` default
    /// and `withSpan` calls become near-zero-cost passthroughs.
    @Flag(
        name: .customLong("trace"),
        inversion: .prefixedNo,
        help: "Enable distributed tracing. Defaults to off."
    )
    public var enabled: Bool = false

    /// OpenTelemetry collector endpoint (e.g. `localhost:4317` for OTLP/gRPC,
    /// or `http://collector:4318` for OTLP/HTTP). The app decides which
    /// protocol to speak; this is just the address.
    @Option(
        name: .customLong("otel-endpoint"),
        help: "OpenTelemetry collector endpoint (e.g. localhost:4317)."
    )
    public var endpoint: String?

    /// Service-name override sent on every span. When `nil`, apps should
    /// fall back to ``HydrogenApplication/identifier``.
    @Option(
        name: .customLong("otel-service-name"),
        help: "Service name attribute for every emitted span. Defaults to the application identifier."
    )
    public var serviceName: String?

    /// Sampling rate in `[0.0, 1.0]`. `nil` defers to the tracer's default
    /// (typically full sampling in dev, head-based at the collector in prod).
    @Option(
        name: .customLong("trace-sample"),
        help: "Span sampling rate as a fraction in [0.0, 1.0]."
    )
    public var sampleRate: Double?

    public init() {}
}
