//
//  HydrogenApplication+Logging.swift
//  swift-hydrogen
//

import Logging

extension HydrogenApplication {
    /// Bootstrap `LoggingSystem` with the given factory.
    ///
    /// `LoggingSystem.bootstrap(_:)` is a one-shot global — call this
    /// once, before any `Logger` is constructed. The conventional
    /// placement is the first line of an overridden `main()`:
    ///
    /// ```swift
    /// @main
    /// struct MyApp: HydrogenApplication {
    ///     // …
    ///     public static func main() async {
    ///         bootstrapLogging()
    ///         await RootCommand.main()
    ///     }
    /// }
    /// ```
    ///
    /// The default factory is ``HydrogenLogging/cloudRunOrStream`` —
    /// JSON for Cloud Logging on Cloud Run / Cloud Run Jobs, plain
    /// stream output everywhere else. Apps wanting different sinks
    /// (Datadog, Honeycomb, multiplexed forwarding, …) supply their own
    /// factory or build a custom ``HydrogenLogging/EnvironmentSelector``.
    ///
    /// - Parameter factory: Produces the `LogHandler` for each new
    ///   logger. The closure runs once per logger label, the first time
    ///   that label is referenced.
    public static func bootstrapLogging(
        using factory: @escaping LogHandlerFactory = HydrogenLogging.cloudRunOrStream.asFactory
    ) {
        LoggingSystem.bootstrap(factory)
    }
}
