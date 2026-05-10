//
//  HydrogenGCP.swift
//  swift-hydrogen
//

import Hydrogen
import Logging

/// Namespace for HydrogenGCP APIs.
///
/// Trait-gated. Enable the `GCP` package trait when adding swift-hydrogen
/// as a dependency to make this target's Cloud Trace tracer / Cloud
/// Trace exporter / Cloud Logging-shaped log handler available.
public enum HydrogenGCP {

    #if HYDROGEN_GCP

    /// `LogHandlerFactory` that constructs a ``GCPLogHandler`` for each
    /// logger label. Pair with ``HydrogenApplication/bootstrapLogging(using:metadataProvider:logLevel:)``
    /// or feed into ``BootstrapPlan/logHandlerFactory``.
    public static let logHandlerFactory: LogHandlerFactory = { label in
        GCPLogHandler(label: label)
    }

    /// Environment selector that picks ``logHandlerFactory`` (Cloud
    /// Logging-shaped JSON) when running on Cloud Run / Cloud Run Jobs
    /// and falls back to plain stream output everywhere else.
    ///
    /// Use this from an app's
    /// ``HydrogenCommand/bootstrap(config:environment:)`` when running
    /// on GCP and you want Cloud Trace/Cloud Logging integration:
    ///
    /// ```swift
    /// func bootstrap(config: ConfigReader, environment: Environment) -> BootstrapPlan {
    ///     var plan = BootstrapPlan()
    ///     plan.logHandlerFactory = HydrogenGCP.cloudRunOrStream.asFactory
    ///     return plan
    /// }
    /// ```
    public static let cloudRunOrStream = HydrogenLogging.EnvironmentSelector(
        entries: [(HydrogenLogging.isCloudRun, logHandlerFactory)],
        fallback: HydrogenLogging.stream
    )

    #endif
}
