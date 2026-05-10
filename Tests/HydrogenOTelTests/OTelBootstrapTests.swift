//
//  OTelBootstrapTests.swift
//  swift-hydrogen
//

#if HYDROGEN_OTEL

import Hydrogen
@testable import HydrogenOTel
import Testing

@Suite("HydrogenOTel.makeBootstrap")
struct OTelBootstrapTests {

    @Test("All-disabled configuration returns an empty plan with no side effects")
    func allDisabledIsEmptyPlan() throws {
        let tracing = try OTelTracingOptions.parse([])
        let metrics = try OTelMetricsOptions.parse([])

        let plan = try HydrogenOTel.makeBootstrap(
            serviceName: "test-svc",
            tracing: tracing,
            metrics: metrics,
            logsEnabled: false
        )

        #expect(plan.isEmpty == true)
        #expect(plan.lifecycleServices.isEmpty)
    }

    @Test("OTelTracingOptions defaults to disabled")
    func tracingDefaultsDisabled() throws {
        let tracing = try OTelTracingOptions.parse([])
        #expect(tracing.enabled == false)
        #expect(tracing.endpoint == nil)
        #expect(tracing.sampleRate == nil)
    }

    @Test("OTelMetricsOptions defaults to disabled")
    func metricsDefaultsDisabled() throws {
        let metrics = try OTelMetricsOptions.parse([])
        #expect(metrics.enabled == false)
        #expect(metrics.endpoint == nil)
    }
}

#endif
