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
    /// Pass a ``Logger/MetadataProvider`` to attach cross-cutting
    /// metadata (request id, authenticated identity, trace id, …) to
    /// every log line emitted by every `Logger` constructed after this
    /// call. Provider state is typically read from `TaskLocal` values
    /// set by request-scoping middleware. Without one, only metadata
    /// the caller passes via `logger.info(metadata:)` is included.
    ///
    /// - Parameters:
    ///   - factory: Produces the `LogHandler` for each new logger. The
    ///     closure runs once per logger label, the first time that
    ///     label is referenced.
    ///   - metadataProvider: Optional cross-cutting metadata source.
    ///     Evaluated on every log call. Defaults to `nil` (no extra
    ///     metadata).
    ///   - logLevel: Default level applied to every handler this
    ///     bootstrap produces. When `nil`, ``HydrogenLogging/resolveLogLevel(envVar:)``
    ///     reads the `LOG_LEVEL` env var; if that's also unset or unparseable,
    ///     `.info` is used. Bootstrap-time only — apps can still scope a
    ///     narrower level on individual `Logger` instances.
    public static func bootstrapLogging(
        using factory: @escaping LogHandlerFactory = HydrogenLogging.cloudRunOrStream.asFactory,
        metadataProvider: Logger.MetadataProvider? = nil,
        logLevel: Logger.Level? = nil
    ) {
        let resolvedLevel = logLevel ?? HydrogenLogging.resolveLogLevel() ?? .info
        // Wrap the caller-supplied factory so every handler gets the
        // resolved level applied at construction. `LogHandler.logLevel`
        // is `var` on the protocol — assignment after init is the
        // documented swift-log path for level overrides.
        let leveledFactory: LogHandlerFactory = { label in
            var handler = factory(label)
            handler.logLevel = resolvedLevel
            return handler
        }
        if let metadataProvider {
            // The (label, provider) factory overload is the swift-log
            // path that wires the global provider through to each
            // Logger. We discard the per-call provider argument because
            // our `LogHandlerFactory` shape only takes a label — swift-
            // log applies the global provider at log call time anyway,
            // independent of whether the handler knows about it.
            LoggingSystem.bootstrap(
                { label, _ in leveledFactory(label) },
                metadataProvider: metadataProvider
            )
        } else {
            LoggingSystem.bootstrap(leveledFactory)
        }
    }
}
