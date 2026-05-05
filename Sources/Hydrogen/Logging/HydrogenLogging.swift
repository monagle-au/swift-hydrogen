//
//  HydrogenLogging.swift
//  swift-hydrogen
//

import Foundation
import Logging

/// A factory that produces a `LogHandler` for a given logger label.
///
/// Used as the closure argument to `LoggingSystem.bootstrap(_:)`, either
/// directly or via ``HydrogenApplication/bootstrapLogging(using:)``.
public typealias LogHandlerFactory = @Sendable (_ label: String) -> any LogHandler

/// Namespace for Hydrogen's logging conveniences: stock `LogHandler`
/// factories and a composable environment-driven selector.
///
/// The intent is to make the default sensible (structured JSON in Cloud
/// Run, plain text on a developer's terminal) without locking apps into
/// any particular sink — every primitive is exposed so apps can compose
/// their own selection or wrap multiple sinks via
/// `MultiplexLogHandler`.
public enum HydrogenLogging {

    // MARK: - Stock factories

    /// swift-log's default stream output (stderr by default in
    /// `StreamLogHandler.standardError`, but stdout reads more naturally
    /// for the interactive CLI case).
    public static let stream: LogHandlerFactory = { label in
        StreamLogHandler.standardOutput(label: label)
    }

    /// JSON-shaped output recognised by Google Cloud Logging. See
    /// ``GCPLogHandler``.
    public static let gcp: LogHandlerFactory = { label in
        GCPLogHandler(label: label)
    }

    // MARK: - Stock predicates

    /// True when the process appears to be running on Cloud Run or a
    /// Cloud Run Job. Both runtimes set the `K_SERVICE` env var to the
    /// service / job name.
    public static let isCloudRun: EnvironmentSelector.Predicate = {
        ProcessInfo.processInfo.environment["K_SERVICE"] != nil
    }

    // MARK: - Default selector

    /// The conventional Hydrogen default: structured JSON when running
    /// on Cloud Run, plain text everywhere else (local dev, ad-hoc CLI
    /// invocations, CI).
    ///
    /// Apps wanting a different mix should construct their own
    /// ``EnvironmentSelector`` rather than mutating this value.
    public static let cloudRunOrStream = EnvironmentSelector(
        entries: [(isCloudRun, gcp)],
        fallback: stream
    )

    // MARK: - EnvironmentSelector

    /// Picks a `LogHandler` factory at bootstrap time by evaluating
    /// predicates against the current process's environment.
    ///
    /// Predicates are evaluated in order; the first match's factory is
    /// adopted. If none match, the `fallback` factory is used.
    ///
    /// ```swift
    /// let selector = HydrogenLogging.EnvironmentSelector(
    ///     entries: [
    ///         ({ ProcessInfo.processInfo.environment["DD_AGENT_HOST"] != nil }, datadogFactory),
    ///         (HydrogenLogging.isCloudRun, HydrogenLogging.gcp),
    ///     ],
    ///     fallback: HydrogenLogging.stream
    /// )
    /// MyApp.bootstrapLogging(using: selector.asFactory)
    /// ```
    public struct EnvironmentSelector: Sendable {

        /// A `@Sendable` predicate fired once at bootstrap time.
        ///
        /// Evaluated with no arguments; should consult `ProcessInfo` or
        /// any other process-global state to decide whether the
        /// associated factory wins.
        public typealias Predicate = @Sendable () -> Bool

        /// One predicate paired with the factory to use when it fires.
        public typealias Entry = (predicate: Predicate, factory: LogHandlerFactory)

        public var entries: [Entry]
        public var fallback: LogHandlerFactory

        public init(entries: [Entry] = [], fallback: @escaping LogHandlerFactory) {
            self.entries = entries
            self.fallback = fallback
        }

        /// Add an entry to the front of the list — useful for adding a
        /// site-specific override on top of an existing selector.
        public func prepending(_ predicate: @escaping Predicate, factory: @escaping LogHandlerFactory) -> Self {
            var copy = self
            copy.entries.insert((predicate, factory), at: 0)
            return copy
        }

        /// Resolve a `LogHandler` for the given label by walking entries.
        public func makeHandler(for label: String) -> any LogHandler {
            for entry in entries where entry.predicate() {
                return entry.factory(label)
            }
            return fallback(label)
        }

        /// The selector as a factory closure suitable for
        /// `LoggingSystem.bootstrap(_:)` and
        /// ``HydrogenApplication/bootstrapLogging(using:)``.
        public var asFactory: LogHandlerFactory {
            { label in self.makeHandler(for: label) }
        }
    }
}
