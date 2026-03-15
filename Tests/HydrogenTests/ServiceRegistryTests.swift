//
//  ServiceRegistryTests.swift
//  swift-hydrogen
//
//  Tests for ServiceValues, ServiceRegistry, and ConcreteServiceEntry.
//

import Testing
import ServiceLifecycle
import Logging
import Configuration
@testable import Hydrogen

// MARK: - Mock ServiceKeys

private struct IntKey: ServiceKey {
    static var defaultValue: Int { 0 }
}

private struct StringKey: ServiceKey {
    static var defaultValue: String { "" }
}

private struct OptionalKey: ServiceKey {
    static var defaultValue: String? { nil }
}

// MARK: - Mock Services

private struct NoOpService: Service, Sendable {
    func run() async throws {
        try await gracefulShutdown()
    }
}

private struct NoOpServiceKey: ServiceKey {
    static var defaultValue: NoOpService? { nil }
}

// A service where K.Value IS itself a Service & Sendable (convenience init path).
// The Value must be non-optional for the convenience init (K.Value: Service & Sendable) to apply.
private struct SelfService: Service, Sendable {
    let id: String
    func run() async throws {
        try await gracefulShutdown()
    }
}

private struct SelfServiceKey: ServiceKey {
    // Value is SelfService directly (not optional) so the convenience init applies.
    static var defaultValue: SelfService { SelfService(id: "") }
}

// MARK: - Helpers

private func makeConfig() -> ConfigReader {
    ConfigReader(provider: EnvironmentVariablesProvider())
}

private let testLogger = Logger(label: "test")

// MARK: - ServiceValues Tests

@Suite("ServiceValues")
struct ServiceValuesTests {

    @Test("Default value is returned when nothing has been set")
    func defaultValueReturnedWhenEmpty() {
        let values = ServiceValues()
        #expect(values[IntKey.self] == 0)
        #expect(values[StringKey.self] == "")
        #expect(values[OptionalKey.self] == nil)
    }

    @Test("Setting and getting a value round-trips correctly")
    func setAndGet() {
        var values = ServiceValues()
        values[IntKey.self] = 42
        #expect(values[IntKey.self] == 42)
    }

    @Test("Multiple keys with different types do not interfere")
    func multipleKeys() {
        var values = ServiceValues()
        values[IntKey.self] = 99
        values[StringKey.self] = "hello"
        #expect(values[IntKey.self] == 99)
        #expect(values[StringKey.self] == "hello")
    }

    @Test("Overwriting a value replaces the previous one")
    func overwriteValue() {
        var values = ServiceValues()
        values[IntKey.self] = 1
        values[IntKey.self] = 2
        #expect(values[IntKey.self] == 2)
    }

    @Test("Setting a value does not affect other keys")
    func isolatedKeyMutation() {
        var values = ServiceValues()
        values[IntKey.self] = 7
        #expect(values[StringKey.self] == "")
    }
}

// MARK: - ServiceRegistry Tests

@Suite("ServiceRegistry")
struct ServiceRegistryTests {

    private func makeEntry(label: String, mode: ServiceLifecycleMode = .persistent) -> any ServiceEntry {
        ConcreteServiceEntry<IntKey>(label: label, mode: mode) { _, _, _ in
            (value: 1, service: NoOpService())
        }
    }

    @Test("Empty registry has no entries")
    func emptyRegistry() {
        let registry = ServiceRegistry()
        #expect(registry.entries.isEmpty)
    }

    @Test("Registered entry is stored")
    func registerStoresEntry() {
        var registry = ServiceRegistry()
        registry.register(IntKey.self, entry: makeEntry(label: "int-service"))
        #expect(registry.entries.count == 1)
    }

    @Test("Multiple distinct keys are all stored")
    func multipleRegistrations() {
        var registry = ServiceRegistry()
        registry.register(IntKey.self, entry: makeEntry(label: "int-service"))
        registry.register(
            StringKey.self,
            entry: ConcreteServiceEntry<StringKey>(label: "string-service", mode: .persistent) { _, _, _ in
                (value: "hello", service: NoOpService())
            }
        )
        #expect(registry.entries.count == 2)
    }

    @Test("Duplicate key registration replaces the old entry")
    func duplicateKeyReplaces() {
        var registry = ServiceRegistry()
        registry.register(IntKey.self, entry: makeEntry(label: "first"))
        registry.register(IntKey.self, entry: makeEntry(label: "second"))
        // Should still be one entry, with the second label
        #expect(registry.entries.count == 1)
        #expect(registry.entries.first?.entry.label == "second")
    }

    @Test("Registration order is preserved for distinct keys")
    func registrationOrderPreserved() {
        var registry = ServiceRegistry()
        registry.register(IntKey.self, entry: makeEntry(label: "first"))
        registry.register(
            StringKey.self,
            entry: ConcreteServiceEntry<StringKey>(label: "second", mode: .persistent) { _, _, _ in
                (value: "", service: NoOpService())
            }
        )
        #expect(registry.entries[0].entry.label == "first")
        #expect(registry.entries[1].entry.label == "second")
    }

    @Test("Duplicate key replacement preserves position in the list")
    func duplicateKeyPreservesPosition() {
        var registry = ServiceRegistry()
        registry.register(IntKey.self, entry: makeEntry(label: "int"))
        registry.register(
            StringKey.self,
            entry: ConcreteServiceEntry<StringKey>(label: "string", mode: .persistent) { _, _, _ in
                (value: "", service: NoOpService())
            }
        )
        // Replace the first entry
        registry.register(IntKey.self, entry: makeEntry(label: "int-updated"))
        // Position 0 should still be the IntKey entry, now with updated label
        #expect(registry.entries[0].entry.label == "int-updated")
        #expect(registry.entries[1].entry.label == "string")
    }
}

// MARK: - ConcreteServiceEntry Tests

@Suite("ConcreteServiceEntry")
struct ConcreteServiceEntryTests {

    @Test("Label and mode are preserved")
    func labelAndModePreserved() {
        let entry = ConcreteServiceEntry<IntKey>(
            label: "my-service",
            mode: .task
        ) { _, _, _ in
            (value: 42, service: NoOpService())
        }
        #expect(entry.label == "my-service")
        #expect(entry.mode == .task)
    }

    @Test("Dependencies are converted to ObjectIdentifiers")
    func dependenciesConvertedToObjectIdentifiers() {
        let entry = ConcreteServiceEntry<IntKey>(
            label: "dependent",
            mode: .persistent,
            dependencies: [StringKey.self, OptionalKey.self]
        ) { _, _, _ in
            (value: 0, service: NoOpService())
        }
        #expect(entry.dependencies.count == 2)
        #expect(entry.dependencies.contains(ObjectIdentifier(StringKey.self)))
        #expect(entry.dependencies.contains(ObjectIdentifier(OptionalKey.self)))
    }

    @Test("Empty dependencies list is stored correctly")
    func emptyDependencies() {
        let entry = ConcreteServiceEntry<IntKey>(
            label: "no-deps",
            mode: .persistent,
            dependencies: []
        ) { _, _, _ in
            (value: 0, service: NoOpService())
        }
        #expect(entry.dependencies.isEmpty)
    }

    @Test("buildAndStore stores the value in ServiceValues and returns a Service")
    func buildAndStoreExplicitTuple() throws {
        let entry = ConcreteServiceEntry<IntKey>(
            label: "store-test",
            mode: .persistent
        ) { _, _, _ in
            (value: 123, service: NoOpService())
        }
        var values = ServiceValues()
        let config = makeConfig()
        _ = try entry.buildAndStore(from: &values, config: config, logger: testLogger)
        #expect(values[IntKey.self] == 123)
    }

    @Test("Convenience init (K.Value: Service & Sendable) builds correctly")
    func convenienceInitBuildsCorrectly() throws {
        // SelfServiceKey.Value is SelfService (non-optional, Service & Sendable),
        // so the convenience init is selected — the returned value IS the service.
        let entry = ConcreteServiceEntry<SelfServiceKey>(
            label: "self-service",
            mode: .task
        ) { _, _, _ in
            SelfService(id: "abc")
        }
        var values = ServiceValues()
        let config = makeConfig()
        _ = try entry.buildAndStore(from: &values, config: config, logger: testLogger)
        #expect(values[SelfServiceKey.self].id == "abc")
    }

    @Test("Build closure receives the current ServiceValues snapshot")
    func buildClosureReceivesCurrentValues() throws {
        // Pre-populate values with a dependency value.
        var values = ServiceValues()
        values[IntKey.self] = 77

        // The entry reads IntKey from the passed ServiceValues and embeds the
        // result in the returned String so we can verify it without a mutable capture.
        let entry = ConcreteServiceEntry<StringKey>(
            label: "reader",
            mode: .persistent
        ) { vals, _, _ in
            let seen = vals[IntKey.self]
            return (value: "saw-\(seen)", service: NoOpService())
        }

        let config = makeConfig()
        _ = try entry.buildAndStore(from: &values, config: config, logger: testLogger)
        #expect(values[StringKey.self] == "saw-77")
    }
}
