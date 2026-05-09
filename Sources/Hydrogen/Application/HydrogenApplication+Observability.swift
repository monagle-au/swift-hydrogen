//
//  HydrogenApplication+Observability.swift
//  swift-hydrogen
//

import Instrumentation
import Tracing

extension HydrogenApplication {
    /// Bootstrap the global ``InstrumentationSystem`` with the given
    /// `Instrument` (typically a `Tracer`).
    ///
    /// `InstrumentationSystem.bootstrap(_:)` is a one-shot global — call
    /// this once, before any code that calls `withSpan`/`startSpan`. The
    /// conventional placement is the first line of an overridden `main()`,
    /// before ``bootstrapLogging(using:metadataProvider:logLevel:)`` so the
    /// logging system can read trace context populated by the tracer.
    ///
    /// ```swift
    /// @main
    /// struct MyApp: HydrogenApplication {
    ///     public static func main() async {
    ///         bootstrapTracing(using: MyTracer(...))
    ///         bootstrapLogging(metadataProvider: ...)
    ///         await RootCommand.main()
    ///     }
    /// }
    /// ```
    ///
    /// Apps that don't ship spans skip this entirely — swift-distributed-
    /// tracing's `NoOpInstrument` is the default when no bootstrap occurs,
    /// so `withSpan` becomes a near-zero-cost passthrough.
    ///
    /// - Parameter instrument: The `Tracer` (or any `Instrument`) to install
    ///   as the process-wide tracing backend. To run several instruments
    ///   concurrently (e.g. a Cloud Trace exporter alongside Datadog),
    ///   pass a `MultiplexInstrument([a, b, …])`.
    public static func bootstrapTracing(using instrument: any Instrument) {
        InstrumentationSystem.bootstrap(instrument)
    }
}
