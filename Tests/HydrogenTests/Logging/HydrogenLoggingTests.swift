//
//  HydrogenLoggingTests.swift
//  swift-hydrogen
//

import Logging
import Synchronization
import Testing
@testable import Hydrogen

/// Records which factory ran. `Mutex` keeps the closure `@Sendable`.
private final class Picked: Sendable {
    private let value = Mutex<String>("")
    func set(_ s: String) { value.withLock { $0 = s } }
    var get: String { value.withLock { $0 } }
}

private final class CallCount: Sendable {
    private let value = Mutex<Int>(0)
    func bump() { value.withLock { $0 += 1 } }
    var get: Int { value.withLock { $0 } }
}

@Suite("HydrogenLogging.EnvironmentSelector")
struct HydrogenLoggingTests {

    @Test("first matching predicate's factory wins")
    func firstMatchWins() {
        let picked = Picked()
        let selector = HydrogenLogging.EnvironmentSelector(
            entries: [
                ({ true }, { _ in picked.set("first"); return StreamLogHandler.standardOutput(label: "x") }),
                ({ true }, { _ in picked.set("second"); return StreamLogHandler.standardOutput(label: "x") }),
            ],
            fallback: { _ in picked.set("fallback"); return StreamLogHandler.standardOutput(label: "x") }
        )
        _ = selector.makeHandler(for: "test")
        #expect(picked.get == "first")
    }

    @Test("falls back when no predicate matches")
    func fallbackUsedWhenNoneMatch() {
        let picked = Picked()
        let selector = HydrogenLogging.EnvironmentSelector(
            entries: [
                ({ false }, { _ in picked.set("no"); return StreamLogHandler.standardOutput(label: "x") }),
            ],
            fallback: { _ in picked.set("fallback"); return StreamLogHandler.standardOutput(label: "x") }
        )
        _ = selector.makeHandler(for: "test")
        #expect(picked.get == "fallback")
    }

    @Test("prepending inserts at the front")
    func prependingPutsEntryFirst() {
        let picked = Picked()
        let base = HydrogenLogging.EnvironmentSelector(
            entries: [
                ({ true }, { _ in picked.set("base"); return StreamLogHandler.standardOutput(label: "x") }),
            ],
            fallback: { _ in picked.set("fallback"); return StreamLogHandler.standardOutput(label: "x") }
        )
        let extended = base.prepending({ true }, factory: { _ in
            picked.set("prepended")
            return StreamLogHandler.standardOutput(label: "x")
        })
        _ = extended.makeHandler(for: "test")
        #expect(picked.get == "prepended")
    }

    @Test("asFactory walks entries per call")
    func asFactoryDelegates() {
        let calls = CallCount()
        let selector = HydrogenLogging.EnvironmentSelector(
            entries: [
                ({ true }, { _ in calls.bump(); return StreamLogHandler.standardOutput(label: "x") }),
            ],
            fallback: { _ in StreamLogHandler.standardOutput(label: "x") }
        )
        let factory = selector.asFactory
        _ = factory("a")
        _ = factory("b")
        #expect(calls.get == 2)
    }

    @Test("predicate is re-evaluated per makeHandler call, not memoised")
    func predicateNotMemoised() {
        let predicateCalls = CallCount()
        let selector = HydrogenLogging.EnvironmentSelector(
            entries: [
                ({ predicateCalls.bump(); return false }, { _ in StreamLogHandler.standardOutput(label: "x") }),
            ],
            fallback: { _ in StreamLogHandler.standardOutput(label: "x") }
        )
        _ = selector.makeHandler(for: "x")
        _ = selector.makeHandler(for: "x")
        _ = selector.makeHandler(for: "x")
        #expect(predicateCalls.get == 3)
    }
}
