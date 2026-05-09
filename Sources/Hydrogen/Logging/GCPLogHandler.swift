//
//  GCPLogHandler.swift
//  swift-hydrogen
//

import Foundation
import Logging
import ServiceContextModule

/// A swift-log `LogHandler` that emits one structured-JSON record per call,
/// shaped for ingestion by Google Cloud Logging.
///
/// Cloud Run, Cloud Run Jobs, and GKE forward stdout/stderr to Cloud
/// Logging. When the captured line is valid JSON, the ingester promotes
/// recognised top-level fields to the log entry's first-class properties
/// (`severity`, `timestamp`, source location, trace, span) and exposes the
/// remainder as `jsonPayload`. The handler emits exactly that shape:
///
/// ```json
/// {"severity":"INFO","time":"2026-05-05T07:05:15.123Z","logger":"acs",
///  "message":"Instance registered",
///  "logging.googleapis.com/sourceLocation":{"file":"…","line":"42","function":"…"},
///  "instance_id":"…","account_id":"…"}
/// ```
///
/// Reference: <https://cloud.google.com/logging/docs/structured-logging>.
///
/// Construct directly to use ad-hoc, or wire through
/// ``HydrogenLogging/gcp`` via ``HydrogenApplication/bootstrapLogging(using:)``.
public struct GCPLogHandler: LogHandler {

    // MARK: - Sink

    /// Synchronous sink for the encoded JSON line (newline already appended).
    /// Defaults to stdout. Tests inject an in-memory sink to assert output.
    public typealias Sink = @Sendable (_ line: String) -> Void

    // MARK: - Configuration

    public let label: String
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?
    public var logLevel: Logger.Level = .info

    /// GCP project ID used to format the `logging.googleapis.com/trace`
    /// field. Cloud Logging requires the full path
    /// `projects/<id>/traces/<traceId>` — the project ID has to be
    /// known at log-write time. When `nil`, trace correlation fields are
    /// suppressed even if a ``LoggingTraceContext`` is present.
    public let gcpProjectID: String?

    private let sink: Sink

    // MARK: - Init

    /// Create a handler writing to standard output (the GCP-recommended
    /// stream — Cloud Logging treats stdout/stderr identically but stdout
    /// reads as the more conventional choice for non-error severities).
    ///
    /// `gcpProjectID` defaults to `GOOGLE_CLOUD_PROJECT` (Cloud Run
    /// injects this automatically). Pass an explicit value when running
    /// outside Cloud Run, or pass `""` to suppress trace correlation
    /// even when a ``LoggingTraceContext`` is set.
    public init(
        label: String,
        metadataProvider: Logger.MetadataProvider? = nil,
        logLevel: Logger.Level = .info,
        gcpProjectID: String? = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"]
    ) {
        self.init(
            label: label,
            metadataProvider: metadataProvider,
            logLevel: logLevel,
            gcpProjectID: gcpProjectID,
            sink: Self.standardOutputSink
        )
    }

    /// Create a handler with a custom sink. Used by tests to capture output
    /// without mutating real stdout.
    public init(
        label: String,
        metadataProvider: Logger.MetadataProvider? = nil,
        logLevel: Logger.Level = .info,
        gcpProjectID: String? = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"],
        sink: @escaping Sink
    ) {
        self.label = label
        self.metadataProvider = metadataProvider
        self.logLevel = logLevel
        self.gcpProjectID = (gcpProjectID?.isEmpty == true) ? nil : gcpProjectID
        self.sink = sink
    }

    // MARK: - LogHandler conformance

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge precedence (lowest → highest): handler.metadata, provider, explicit.
        // Same order swift-log's StreamLogHandler uses.
        var merged = self.metadata
        if let provided = metadataProvider?.get(), !provided.isEmpty {
            merged.merge(provided, uniquingKeysWith: { _, new in new })
        }
        if let explicit = explicitMetadata, !explicit.isEmpty {
            merged.merge(explicit, uniquingKeysWith: { _, new in new })
        }

        // Cloud Trace correlation. When the active task carries a
        // `LoggingTraceContext` and we know our project ID, emit the
        // three magic keys Cloud Logging reads to render the "view trace"
        // link on each log entry. Caller-supplied metadata wins on
        // collision — `uniquingKeysWith: { current, _ in current }`
        // preserves whatever was already merged from explicit/provider/
        // handler sources.
        if let projectID = gcpProjectID,
           let trace = ServiceContext.current?.loggingTraceContext {
            merged.merge([
                "logging.googleapis.com/trace": .string("projects/\(projectID)/traces/\(trace.traceID)"),
                "logging.googleapis.com/spanId": .string(trace.spanID),
                "logging.googleapis.com/trace_sampled": .string(trace.sampled ? "true" : "false"),
            ], uniquingKeysWith: { existing, _ in existing })
        }

        let payload = LogPayload(
            severity: Self.gcpSeverity(for: level),
            time: Self.iso8601.string(from: Date()),
            logger: label,
            message: message.description,
            sourceLocation: .init(file: file, line: String(line), function: function),
            metadata: merged
        )

        guard let data = try? Self.encoder.encode(payload),
              let line = String(data: data, encoding: .utf8)
        else {
            // Encoding failure is unreachable for well-formed payloads; the
            // metadata flatten always emits string values. Drop on the floor
            // rather than throwing — log handlers can't propagate errors.
            return
        }
        sink(line + "\n")
    }

    // MARK: - Encoding

    /// `LogPayload` is encoded with two adjustments to match Cloud Logging's
    /// expectations: the source-location field uses the literal key
    /// `"logging.googleapis.com/sourceLocation"`, and metadata entries are
    /// flattened to top-level string keys (Cloud Logging exposes them under
    /// `jsonPayload`). Both shapes are easier to express via a custom
    /// `Encodable` implementation than a `CodingKeys` enum.
    private struct LogPayload: Encodable {
        let severity: String
        let time: String
        let logger: String
        let message: String
        let sourceLocation: SourceLocation
        let metadata: Logger.Metadata

        struct SourceLocation: Encodable {
            let file: String
            let line: String
            let function: String
        }

        private struct StringKey: CodingKey {
            let stringValue: String
            init(_ s: String) { self.stringValue = s }
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue _: Int) { nil }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: StringKey.self)
            try container.encode(severity, forKey: StringKey("severity"))
            try container.encode(time, forKey: StringKey("time"))
            try container.encode(logger, forKey: StringKey("logger"))
            try container.encode(message, forKey: StringKey("message"))
            try container.encode(
                sourceLocation,
                forKey: StringKey("logging.googleapis.com/sourceLocation")
            )
            // Flatten metadata. Reserved key names — `severity`, `time`,
            // `logger`, `message`, the source-location key — are skipped to
            // avoid clobbering the typed fields above; logging metadata that
            // collides loses to the structural field.
            for (key, value) in metadata {
                guard !Self.reservedKeys.contains(key) else { continue }
                try container.encode(Self.flatten(value), forKey: StringKey(key))
            }
        }

        private static let reservedKeys: Set<String> = [
            "severity", "time", "logger", "message",
            "logging.googleapis.com/sourceLocation",
        ]

        /// Flatten a `Logger.MetadataValue` to its string description for
        /// JSON output. This loses structural fidelity (a stringified
        /// `[1, 2, 3]` becomes `"[1, 2, 3]"`) but preserves searchability in
        /// Cloud Logging without the ingester rejecting unknown shapes.
        /// Trade structure for compatibility.
        private static func flatten(_ value: Logger.MetadataValue) -> String {
            switch value {
            case .string(let s): return s
            case .stringConvertible(let c): return c.description
            case .array, .dictionary: return value.description
            }
        }
    }

    // MARK: - Severity mapping

    /// Map swift-log levels to the GCP `LogSeverity` enum strings.
    /// Reference: <https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#logseverity>.
    static func gcpSeverity(for level: Logger.Level) -> String {
        switch level {
        case .trace, .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    // MARK: - Internals

    /// ISO 8601 with millisecond precision and explicit Z. GCP accepts other
    /// RFC 3339 forms but this shape sorts cleanly as a string.
    ///
    /// `nonisolated(unsafe)` is correct here: `ISO8601DateFormatter` is
    /// documented thread-safe for `string(from:)` once its `formatOptions`
    /// are set (Apple's docs and Foundation source agree). The compiler
    /// flags any non-`Sendable` global, so we opt out explicitly.
    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Same rationale as ``iso8601`` — `JSONEncoder.encode` is thread-safe
    /// after configuration; the type is just not annotated `Sendable`.
    nonisolated(unsafe) private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Stable key ordering helps log diff-readability. Disable for prod
        // throughput if it ever shows up in profiles.
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    // MARK: - Standard output sink

    /// Default sink: write atomically to stdout. Each call performs a single
    /// `FileHandle.write` for a single line, which is atomic at the syscall
    /// level when the write fits in `PIPE_BUF` (typically ≥512 bytes —
    /// enough for any sensible structured log line).
    static let standardOutputSink: Sink = { line in
        guard let data = line.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
