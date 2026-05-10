//
//  TracingOptionsTests.swift
//  swift-hydrogen
//

import ArgumentParser
@testable import Hydrogen
import Testing

@Suite("TracingOptions")
struct TracingOptionsTests {

    @Test("Defaults: tracing disabled, all fields nil")
    func defaults() throws {
        let opts = try TracingOptions.parse([])
        #expect(opts.enabled == false)
        #expect(opts.endpoint == nil)
        #expect(opts.serviceName == nil)
        #expect(opts.sampleRate == nil)
    }

    @Test("--trace flag enables tracing")
    func traceFlag() throws {
        let opts = try TracingOptions.parse(["--trace"])
        #expect(opts.enabled == true)
    }

    @Test("--no-trace flag disables tracing explicitly")
    func noTraceFlag() throws {
        let opts = try TracingOptions.parse(["--no-trace"])
        #expect(opts.enabled == false)
    }

    @Test("--otel-endpoint and --otel-service-name parse")
    func otelEndpointAndServiceName() throws {
        let opts = try TracingOptions.parse([
            "--trace",
            "--otel-endpoint", "localhost:4317",
            "--otel-service-name", "checkout-svc",
        ])
        #expect(opts.endpoint == "localhost:4317")
        #expect(opts.serviceName == "checkout-svc")
    }

    @Test("--trace-sample parses as Double")
    func sampleRateParses() throws {
        let opts = try TracingOptions.parse(["--trace", "--trace-sample", "0.25"])
        #expect(opts.sampleRate == 0.25)
    }
}

@Suite("MetricsOptions")
struct MetricsOptionsTests {

    @Test("Defaults: metrics disabled, all fields nil")
    func defaults() throws {
        let opts = try MetricsOptions.parse([])
        #expect(opts.enabled == false)
        #expect(opts.endpoint == nil)
        #expect(opts.intervalSeconds == nil)
    }

    @Test("--metrics flag enables metrics")
    func metricsFlag() throws {
        let opts = try MetricsOptions.parse(["--metrics"])
        #expect(opts.enabled == true)
    }

    @Test("--metrics-endpoint and --metrics-interval parse")
    func endpointAndInterval() throws {
        let opts = try MetricsOptions.parse([
            "--metrics",
            "--metrics-endpoint", "localhost:4318",
            "--metrics-interval", "30",
        ])
        #expect(opts.endpoint == "localhost:4318")
        #expect(opts.intervalSeconds == 30)
    }
}
