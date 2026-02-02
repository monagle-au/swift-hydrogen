import Testing
@testable import Hydrogen

@MainActor
@Suite("ApplicationRegistry")
struct ApplicationRegistryTests {
    struct DummyResourceKey: ResourceKey {
        static var name: String { "dummy.resource" }
        typealias Value = Int
    }
    
    let serviceA = ServiceKey("service.a")
    let serviceB = ServiceKey("service.b")

    @Test("Resources: initially empty, then retrievable after registration")
    func resourcesRegistrationAndLookup() async throws {
        var builder = ApplicationRegistryBuilder()
        #expect(builder.build().resource(DummyResourceKey.self) == nil)

        builder.register(DummyResourceKey.self) { _ in 42 }
        let registry = builder.build()

        let def = try #require(registry.resource(DummyResourceKey.self))
        // Build using a minimal ApplicationContext to validate closure wiring
        let dummyConfig = buildConfigReader()
        let ctx = ApplicationContext(config: dummyConfig, registry: registry)
        let built = try def.build(ctx)
        let value = try #require(built as? Int)
        #expect(value == 42)
    }
}

// Minimal dummy Service implementation for testing service registration/building
import ServiceLifecycle

private struct DummyService: Service {
    let label: String
    func run() async throws {}
}

private func buildConfigReader() -> ConfigReader {
    ConfigReader(providers: [InMemoryProvider(values: [:])])
}

