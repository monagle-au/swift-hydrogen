//
//  LoggingOptions.swift
//  swift-hydrogen
//

import ArgumentParser
import Logging

/// Reusable `ParsableArguments` for command-line logging configuration.
///
/// Compose into a ``HydrogenCommand`` via `@OptionGroup` and consume the
/// values inside ``HydrogenCommand/bootstrap(config:environment:)`` to drive
/// the ``BootstrapPlan``:
///
/// ```swift
/// struct Serve: PersistentCommand {
///     typealias App = MyApp
///     @OptionGroup var logging: LoggingOptions
///     var requiredServices: [any ServiceKey.Type] { [] }
///
///     func bootstrap(config: ConfigReader, environment: Environment) -> BootstrapPlan {
///         var plan = BootstrapPlan()
///         plan.logLevel = logging.resolvedLogLevel
///         plan.logHandlerFactory = logging.format.factory(default: HydrogenLogging.cloudRunOrStream.asFactory)
///         return plan
///     }
/// }
/// ```
///
/// Apps that want different flag spellings, additional options (e.g.
/// `--log-target=file:/var/log/app.log`), or to skip these flags entirely
/// can write their own `ParsableArguments` — these types are conveniences,
/// not requirements.
public struct LoggingOptions: ParsableArguments, Sendable {
    /// The desired log level. Accepts the swift-log level names
    /// (`trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical`)
    /// case-insensitively.
    @Option(
        name: .customLong("log-level"),
        help: "Minimum log level: trace, debug, info, notice, warning, error, critical."
    )
    public var logLevel: String?

    /// Output format selection. `.auto` defers to the bootstrap factory's
    /// default selection (e.g. ``HydrogenLogging/cloudRunOrStream``).
    @Option(
        name: .customLong("log-format"),
        help: "Output format: auto, json, text. Defaults to auto."
    )
    public var format: LogFormat = .auto

    public init() {}

    /// Parse ``logLevel`` into a `Logger.Level`. Returns `nil` when the flag
    /// was not supplied or the value isn't recognised — the
    /// ``BootstrapCoordinator`` then falls back to the `LOG_LEVEL` env var
    /// or `.info`.
    public var resolvedLogLevel: Logger.Level? {
        guard let raw = logLevel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty
        else { return nil }
        return Logger.Level(rawValue: raw)
    }

    public enum LogFormat: String, CaseIterable, ExpressibleByArgument, Sendable {
        /// Defer to the supplied default factory (e.g. JSON in Cloud Run,
        /// plain text on a developer's terminal).
        case auto
        /// Force structured JSON output via ``GCPLogHandler``.
        case json
        /// Force plain stream output regardless of environment.
        case text

        /// Resolve the `LogHandlerFactory` for this format. Pass the
        /// fallback factory (used when ``LogFormat/auto`` is selected).
        public func factory(default fallback: @escaping LogHandlerFactory) -> LogHandlerFactory {
            switch self {
            case .auto: return fallback
            case .json: return HydrogenLogging.gcp
            case .text: return HydrogenLogging.stream
            }
        }
    }
}
