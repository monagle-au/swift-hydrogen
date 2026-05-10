//
//  LoggingOptionsTests.swift
//  swift-hydrogen
//

import ArgumentParser
@testable import Hydrogen
import Logging
import Testing

@Suite("LoggingOptions")
struct LoggingOptionsTests {

    @Test("Defaults: empty when no flags supplied")
    func defaults() throws {
        let opts = try LoggingOptions.parse([])
        #expect(opts.logLevel == nil)
        #expect(opts.format == .auto)
        #expect(opts.resolvedLogLevel == nil)
    }

    @Test("--log-level=debug parses into Logger.Level.debug")
    func logLevelDebug() throws {
        let opts = try LoggingOptions.parse(["--log-level", "debug"])
        #expect(opts.resolvedLogLevel == .debug)
    }

    @Test("--log-level value is matched case-insensitively")
    func logLevelCaseInsensitive() throws {
        let opts = try LoggingOptions.parse(["--log-level", "WARNING"])
        #expect(opts.resolvedLogLevel == .warning)
    }

    @Test("--log-level=garbage resolves to nil so the bootstrap can fall back")
    func logLevelGarbage() throws {
        let opts = try LoggingOptions.parse(["--log-level", "garbage"])
        #expect(opts.resolvedLogLevel == nil)
    }

    @Test("--log-format=json picks the GCP factory")
    func formatJSON() throws {
        let opts = try LoggingOptions.parse(["--log-format", "json"])
        #expect(opts.format == .json)
    }

    @Test("--log-format=text picks the stream factory")
    func formatText() throws {
        let opts = try LoggingOptions.parse(["--log-format", "text"])
        #expect(opts.format == .text)
    }
}
