import Testing
import ServiceLifecycle
import Configuration
@testable import Hydrogen

@MainActor
@Suite("ApplicationRegistry Tests")
struct ApplicationRegistryTests {
    
    // MARK: - Test Resources
    
    struct CounterResource: ApplicationResource {
        static var name: String { "counter.resource" }
        typealias Value = Int
        
        static func build(context: ApplicationContext) throws -> Int {
            42
        }
    }
    
    struct DatabaseResource: ApplicationResource {
        static var name: String { "database.resource" }
        typealias Value = String
        
        static func build(context: ApplicationContext) throws -> String {
            "postgresql://localhost/testdb"
        }
    }
    
    struct ThrowingResource: ApplicationResource {
        static var name: String { "throwing.resource" }
        typealias Value = String
        
        struct BuildError: Error {}
        
        static func build(context: ApplicationContext) throws -> String {
            throw BuildError()
        }
    }
    
    // MARK: - Test Services
    
    struct BasicService: ApplicationService {
        static func build(context: ApplicationContext) throws -> BasicService {
            BasicService()
        }
        
        func run() async throws {}
    }
    
    struct ServiceWithDependencies: ApplicationService {
        static var dependencies: [any ApplicationService.Type] {
            [BasicService.self]
        }
        
        static func build(context: ApplicationContext) throws -> ServiceWithDependencies {
            ServiceWithDependencies()
        }
        
        func run() async throws {}
    }
    
    struct ServiceWithCustomTermination: ApplicationService {
        static var successTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? {
            .gracefullyShutdownGroup
        }
        
        static var failureTerminationBehavior: ServiceGroupConfiguration.ServiceConfiguration.TerminationBehavior? {
            .ignore
        }
        
        static func build(context: ApplicationContext) throws -> ServiceWithCustomTermination {
            ServiceWithCustomTermination()
        }
        
        func run() async throws {}
    }
    
    struct JobService: ApplicationJob {
        static func build(context: ApplicationContext) throws -> JobService {
            JobService()
        }
        
        func run() async throws {}
    }
    
    // MARK: - Helper
    
    func buildConfigReader() -> ConfigReader {
        ConfigReader(providers: [InMemoryProvider(values: [:])])
    }
    
    func buildContext(registry: ApplicationRegistry) -> ApplicationContext {
        ApplicationContext(
            identifier: "test",
            config: buildConfigReader(),
            registry: registry
        )
    }
    
    // MARK: - Resource Tests
    
    @Test("Empty registry returns nil for unregistered resource")
    func emptyRegistryReturnsNilForResource() async throws {
        let builder = ApplicationRegistryBuilder()
        let registry = builder.build()
        
        #expect(registry.resource(CounterResource.self) == nil)
    }
    
    @Test("Resource registration and lookup")
    func resourceRegistrationAndLookup() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(CounterResource.self)
        
        let registry = builder.build()
        let resourceType = try #require(registry.resource(CounterResource.self))
        
        #expect(resourceType.name == "counter.resource")
    }
    
    @Test("Multiple resource registration")
    func multipleResourceRegistration() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(CounterResource.self)
        builder.register(DatabaseResource.self)
        
        let registry = builder.build()
        
        #expect(registry.resource(CounterResource.self) != nil)
        #expect(registry.resource(DatabaseResource.self) != nil)
    }
    
    @Test("Resource building through context")
    func resourceBuildingThroughContext() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(CounterResource.self)
        
        let registry = builder.build()
        let context = buildContext(registry: registry)
        
        let value = try context.resolve(CounterResource.self)
        #expect(value == 42)
    }
    
    @Test("Resource caching in context")
    func resourceCachingInContext() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(CounterResource.self)
        
        let registry = builder.build()
        let context = buildContext(registry: registry)
        
        let value1 = try context.resolve(CounterResource.self)
        let value2 = try context.resolve(CounterResource.self)
        
        #expect(value1 == 42)
        #expect(value2 == 42)
        // Both should be the same instance (cached)
    }
    
    @Test("Resource building failure propagates error")
    func resourceBuildingFailurePropagatesError() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(ThrowingResource.self)
        
        let registry = builder.build()
        let context = buildContext(registry: registry)
        
        #expect(throws: ThrowingResource.BuildError.self) {
            try context.resolve(ThrowingResource.self)
        }
    }
    
    @Test("Resolving unregistered resource throws error")
    func resolvingUnregisteredResourceThrowsError() async throws {
        let builder = ApplicationRegistryBuilder()
        let registry = builder.build()
        let context = buildContext(registry: registry)
        
        #expect(throws: ApplicationRunner.Error.self) {
            try context.resolve(CounterResource.self)
        }
    }
    
    // MARK: - Service Tests
    
    @Test("Empty registry returns nil for unregistered service")
    func emptyRegistryReturnsNilForService() async throws {
        let builder = ApplicationRegistryBuilder()
        let registry = builder.build()
        
        #expect(registry.service(BasicService.self) == nil)
    }
    
    @Test("Service registration and lookup")
    func serviceRegistrationAndLookup() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(BasicService.self)
        
        let registry = builder.build()
        let definition = try #require(registry.service(BasicService.self))
        
        #expect(definition.dependencies.isEmpty)
    }
    
    @Test("Multiple service registration")
    func multipleServiceRegistration() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(BasicService.self)
        builder.register(ServiceWithDependencies.self)
        
        let registry = builder.build()
        
        #expect(registry.service(BasicService.self) != nil)
        #expect(registry.service(ServiceWithDependencies.self) != nil)
    }
    
    @Test("Service with dependencies")
    func serviceWithDependencies() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(ServiceWithDependencies.self)
        
        let registry = builder.build()
        let definition = try #require(registry.service(ServiceWithDependencies.self))
        
        #expect(definition.dependencies.count == 1)
        #expect(definition.dependencies.first is BasicService.Type)
    }
    
    @Test("Service building through context")
    func serviceBuildingThroughContext() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(BasicService.self)
        
        let registry = builder.build()
        let context = buildContext(registry: registry)
        
        let definition = try #require(registry.service(BasicService.self))
        let service = try definition.build(context)
        
        #expect(service is BasicService)
    }
    
    // MARK: - Service Termination Behavior Tests
    
    @Test("Default service has no termination behaviors")
    func defaultServiceHasNoTerminationBehaviors() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(BasicService.self)
        
        let registry = builder.build()
        let definition = try #require(registry.service(BasicService.self))
        
        #expect(definition.successTerminationBehavior == nil)
        #expect(definition.failureTerminationBehavior == nil)
    }
    
    @Test("Service with custom termination behaviors")
    func serviceWithCustomTerminationBehaviors() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(ServiceWithCustomTermination.self)
        
        let registry = builder.build()
        let definition = try #require(registry.service(ServiceWithCustomTermination.self))
        
        #expect(definition.successTerminationBehavior?.description == "gracefullyShutdownGroup")
        #expect(definition.failureTerminationBehavior?.description == "ignore")
    }
    
    @Test("Job service has graceful shutdown on success")
    func jobServiceHasGracefulShutdownOnSuccess() async throws {
        var builder = ApplicationRegistryBuilder()
        builder.register(JobService.self)
        
        let registry = builder.build()
        let definition = try #require(registry.service(JobService.self))
        
        #expect(definition.successTerminationBehavior?.description == "gracefullyShutdownGroup")
        // Jobs use default failure behavior (nil)
        #expect(definition.failureTerminationBehavior == nil)
    }
    
    // MARK: - IdentifiableByType Tests
    
    @Test("Different resource types have different IDs")
    func differentResourceTypesHaveDifferentIDs() async throws {
        #expect(CounterResource.id != DatabaseResource.id)
    }
    
    @Test("Different service types have different IDs")
    func differentServiceTypesHaveDifferentIDs() async throws {
        #expect(BasicService.id != ServiceWithDependencies.id)
    }
    
    @Test("Same type has consistent ID")
    func sameTypeHasConsistentID() async throws {
        let id1 = CounterResource.id
        let id2 = CounterResource.id
        
        #expect(id1 == id2)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full registry with resources and services")
    func fullRegistryWithResourcesAndServices() async throws {
        var builder = ApplicationRegistryBuilder()
        
        // Register resources
        builder.register(CounterResource.self)
        builder.register(DatabaseResource.self)
        
        // Register services
        builder.register(BasicService.self)
        builder.register(ServiceWithDependencies.self)
        builder.register(JobService.self)
        
        let registry = builder.build()
        
        // Verify all registrations
        #expect(registry.resource(CounterResource.self) != nil)
        #expect(registry.resource(DatabaseResource.self) != nil)
        #expect(registry.service(BasicService.self) != nil)
        #expect(registry.service(ServiceWithDependencies.self) != nil)
        #expect(registry.service(JobService.self) != nil)
        
        // Test resource resolution
        let context = buildContext(registry: registry)
        let counterValue = try context.resolve(CounterResource.self)
        let dbValue = try context.resolve(DatabaseResource.self)
        
        #expect(counterValue == 42)
        #expect(dbValue == "postgresql://localhost/testdb")
    }
    
    @Test("Builder can create multiple independent registries")
    func builderCanCreateMultipleIndependentRegistries() async throws {
        var builder1 = ApplicationRegistryBuilder()
        builder1.register(CounterResource.self)
        let registry1 = builder1.build()
        
        var builder2 = ApplicationRegistryBuilder()
        builder2.register(DatabaseResource.self)
        let registry2 = builder2.build()
        
        // Registry 1 has Counter but not Database
        #expect(registry1.resource(CounterResource.self) != nil)
        #expect(registry1.resource(DatabaseResource.self) == nil)
        
        // Registry 2 has Database but not Counter
        #expect(registry2.resource(DatabaseResource.self) != nil)
        #expect(registry2.resource(CounterResource.self) == nil)
    }
}
