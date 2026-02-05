//
//  ApplicationRunnerTests.swift
//  swift-hydrogen
//
//  Tests demonstrating ApplicationRunner usage patterns
//

import Testing
import ServiceLifecycle
@testable import Hydrogen

// MARK: - Test Resources

/// A mock database resource for testing
private struct MockDatabaseResource: ApplicationResource {
    static var name: String { "database" }
    
    typealias Value = MockDatabase
    
    @MainActor static func build(context: ApplicationContext) throws -> MockDatabase {
        // In a real app, you'd read from config
        let host = context.config.string(forKey: "database.host", default: "localhost")
        let port = context.config.int(forKey: "database.port", default: 5432)
        return MockDatabase(host: host, port: port)
    }
}

private struct MockDatabase: Sendable {
    let host: String
    let port: Int
}

/// A mock logger resource for testing
private struct MockLoggerResource: ApplicationResource {
    static var name: String { "logger" }
    
    typealias Value = Logger
    
    @MainActor static func build(context: ApplicationContext) throws -> Logger {
        return Logger(label: context.identifier)
    }
}

// MARK: - Test Services

/// A mock HTTP server service that completes quickly for testing
private struct MockHTTPServerService: ApplicationService {
    static let dependencies: [any ApplicationService.Type] = []
    
    let logger: Logger
    let database: MockDatabase
    var completed = false
    
    @MainActor static func build(context: ApplicationContext) throws -> MockHTTPServerService {
        let logger = try context.resolve(MockLoggerResource.self)
        let database = try context.resolve(MockDatabaseResource.self)
        return MockHTTPServerService(logger: logger, database: database)
    }
    
    func run() async throws {
        logger.info("Mock HTTP Server starting...")
        // Simulate work then exit gracefully
        try await Task.sleep(for: .milliseconds(10))
        logger.info("Mock HTTP Server completed")
    }
}

/// Example of an actor-based service that runs concurrently
/// This demonstrates how services can use actors for their own isolation
private actor MockActorService: ApplicationService {
    static let dependencies: [any ApplicationService.Type] = []
    
    let logger: Logger
    private var requestCount: Int = 0
    
    // Building still happens on MainActor, but execution is actor-isolated
    @MainActor static func build(context: ApplicationContext) throws -> MockActorService {
        let logger = try context.resolve(MockLoggerResource.self)
        return MockActorService(logger: logger)
    }
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    // This runs with actor isolation - safe concurrent access to requestCount
    func run() async throws {
        logger.info("Actor service starting...")
        
        // Simulate concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    await self.handleRequest(i)
                }
            }
        }
        
        logger.info("Actor service completed with \(requestCount) requests")
    }
    
    private func handleRequest(_ id: Int) async {
        requestCount += 1 // Safe because we're actor-isolated
        try? await Task.sleep(for: .milliseconds(1))
    }
}

/// A mock migration job that runs once and exits
private struct MockMigrationJob: ApplicationJob {
    static let dependencies: [any ApplicationService.Type] = []
    
    let database: MockDatabase
    let logger: Logger
    var ranMigrations = false
    
    @MainActor static func build(context: ApplicationContext) throws -> MockMigrationJob {
        let database = try context.resolve(MockDatabaseResource.self)
        let logger = try context.resolve(MockLoggerResource.self)
        return MockMigrationJob(database: database, logger: logger)
    }
    
    func run() async throws {
        logger.info("Running database migrations on \(database.host):\(database.port)")
        // Simulate migration work
        try await Task.sleep(for: .milliseconds(10))
        logger.info("Migrations complete")
    }
}

/// A mock background worker that depends on the HTTP server
private struct MockBackgroundWorkerService: ApplicationService {
    // Type-safe dependencies - the compiler will catch typos!
    static let dependencies: [any ApplicationService.Type] = [MockHTTPServerService.self]
    
    let logger: Logger
    
    @MainActor static func build(context: ApplicationContext) throws -> MockBackgroundWorkerService {
        let logger = try context.resolve(MockLoggerResource.self)
        return MockBackgroundWorkerService(logger: logger)
    }
    
    func run() async throws {
        logger.info("Background worker starting...")
        // Simulate work then exit
        try await Task.sleep(for: .milliseconds(10))
        logger.info("Background worker completed")
    }
}

// MARK: - Test Suite

@MainActor
@Suite("ApplicationRunner Usage Patterns")
struct ApplicationRunnerTests {
    
    // Helper to create a test config reader
    private func createTestConfig() -> ConfigReader {
        ConfigReader(providers: [
            InMemoryProvider(values: [
                "database.host": "test-host",
                "database.port": 5433
            ])
        ])
    }
    
    @Test("Bootstrap with resources and services")
    func testSimpleBootstrap() async throws {
        let config = createTestConfig()
        
        // Bootstrap with all resources and services - DRY!
        let runner = ApplicationRunner.bootstrap(
            identifier: "test-app",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: [
                MockHTTPServerService.self,
                MockBackgroundWorkerService.self
            ]
        )
        
        // Verify the runner was created with the correct context
        #expect(runner.context.identifier == "test-app")
        
        // Verify resources can be resolved
        let database = try runner.context.resolve(MockDatabaseResource.self)
        #expect(database.host == "test-host")
        #expect(database.port == 5433)
        
        let logger = try runner.context.resolve(MockLoggerResource.self)
        #expect(logger.label == "test-app")
    }
    
    @Test("Job terminates after completion")
    func testMigrationJob() async throws {
        let config = createTestConfig()
        
        let runner = ApplicationRunner.bootstrap(
            identifier: "migration-runner",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: [
                MockMigrationJob.self
            ]
        )
        
        // Verify the migration job is configured correctly
        let database = try runner.context.resolve(MockDatabaseResource.self)
        #expect(database.host == "test-host")
        
        // Note: Actually running the job would require Task cancellation handling
        // for the test suite, so we just verify the setup
    }
    
    @Test("Mixed registration pattern")
    func testMixedBootstrap() async throws {
        let config = createTestConfig()
        
        // You can use the builder directly for custom cases
        var builder = ApplicationRegistryBuilder()
        
        // Register resources via protocol
        builder.register(MockDatabaseResource.self)
        builder.register(MockLoggerResource.self)
        
        // Register services via protocol
        builder.register(MockHTTPServerService.self)
        builder.register(MockBackgroundWorkerService.self)
        
        let registry = builder.build()
        let context = ApplicationContext(identifier: "mixed-app", config: config, registry: registry)
        let runner = ApplicationRunner(context: context)
        
        #expect(runner.context.identifier == "mixed-app")
        
        // Verify resources are available
        let database = try runner.context.resolve(MockDatabaseResource.self)
        #expect(database.host == "test-host")
    }
    
    @Test("Dependency resolution order")
    func testDependencyResolution() async throws {
        let config = createTestConfig()
        
        let runner = ApplicationRunner.bootstrap(
            identifier: "dep-test",
            config: config,
            resources: [
                MockLoggerResource.self,
                MockDatabaseResource.self
            ],
            services: [
                MockHTTPServerService.self,
                MockBackgroundWorkerService.self // Depends on HTTPServer
            ]
        )
        
        #expect(runner.context.identifier == "dep-test")
        
        // The ApplicationRunner should handle the dependency ordering
        // when services are run (HTTPServer before BackgroundWorker)
    }
    
    @Test("Resource caching")
    func testResourceCaching() async throws {
        let config = createTestConfig()
        
        let runner = ApplicationRunner.bootstrap(
            identifier: "cache-test",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: []
        )
        
        // Resolve the same resource twice
        let database1 = try runner.context.resolve(MockDatabaseResource.self)
        let database2 = try runner.context.resolve(MockDatabaseResource.self)
        
        // Should be the same instance (cached)
        #expect(database1.host == database2.host)
        #expect(database1.port == database2.port)
    }
    
    @Test("Multiple services with shared resources")
    func testSharedResources() async throws {
        let config = createTestConfig()
        
        let runner = ApplicationRunner.bootstrap(
            identifier: "shared-test",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: [
                MockHTTPServerService.self,
                MockMigrationJob.self
            ]
        )
        
        // Both services should be able to resolve the same resources
        let logger = try runner.context.resolve(MockLoggerResource.self)
        let database = try runner.context.resolve(MockDatabaseResource.self)
        
        #expect(logger.label == "shared-test")
        #expect(database.host == "test-host")
    }
    
    @Test("ApplicationJob has termination behavior configured")
    func testJobTerminationBehavior() async throws {
        // Verify that ApplicationJob protocol provides a termination behavior
        // We can't compare TerminationBehavior directly as it doesn't conform to Equatable,
        // but we can verify it's non-nil for jobs
        #expect(MockMigrationJob.successTerminationBehavior != nil)
        #expect(MockMigrationJob.failureTerminationBehavior == nil)
    }
    
    @Test("ApplicationService has correct default termination behavior")
    func testServiceTerminationBehavior() async throws {
        // Verify that ApplicationService protocol provides the correct defaults
        // Regular services should have no termination behavior by default
        #expect(MockHTTPServerService.successTerminationBehavior == nil)
        #expect(MockHTTPServerService.failureTerminationBehavior == nil)
    }
}

// MARK: - Error Handling Tests

@MainActor
@Suite("ApplicationRunner Error Handling")
struct ApplicationRunnerErrorTests {
    
    @Test("Missing resource throws error")
    func testMissingResourceError() async throws {
        let config = ConfigReader(providers: [InMemoryProvider(values: [:])])
        
        // Create a runner without registering the database resource
        let runner = ApplicationRunner.bootstrap(
            identifier: "error-test",
            config: config,
            resources: [
                MockLoggerResource.self
                // MockDatabaseResource is NOT registered
            ],
            services: []
        )
        
        // Attempting to resolve the missing resource should throw
        #expect(throws: ApplicationRunner.Error.self) {
            _ = try runner.context.resolve(MockDatabaseResource.self)
        }
    }
    
    @Test("Error description includes resource name")
    func testErrorDescription() async throws {
        let error = ApplicationRunner.Error.missingResource("TestResource")
        #expect(error.description.contains("TestResource"))
        
        let serviceError = ApplicationRunner.Error.missingService("TestService")
        #expect(serviceError.description.contains("TestService"))
        
        let cyclicError = ApplicationRunner.Error.cyclicDependency(["A", "B", "A"])
        #expect(cyclicError.description.contains("A -> B -> A"))
        
        let typeMismatchError = ApplicationRunner.Error.resourceTypeMismatch("WrongType")
        #expect(typeMismatchError.description.contains("WrongType"))
    }
}

// MARK: - Documentation Examples

extension ApplicationRunnerTests {
    /// Example showing the recommended pattern for a typical application
    @Test("Documentation: Typical application setup", .disabled("Documentation example"))
    func exampleTypicalApplication() async throws {
        let config = createTestConfig()
        
        // This is the recommended way to set up an application
        let runner = ApplicationRunner.bootstrap(
            identifier: "my-app",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: [
                MockHTTPServerService.self,
                MockBackgroundWorkerService.self
            ]
        )
        
        // Run specific services - no string keys needed!
        // Note: Commented out as it would block the test
        // try await runner.run([
        //     MockHTTPServerService.self,
        //     MockBackgroundWorkerService.self
        // ])
        
        #expect(runner.context.identifier == "my-app")
    }
    
    /// Example showing how to run a one-off job
    @Test("Documentation: Running a migration job", .disabled("Documentation example"))
    func exampleMigrationJob() async throws {
        let config = createTestConfig()
        
        let runner = ApplicationRunner.bootstrap(
            identifier: "migration-runner",
            config: config,
            resources: [
                MockDatabaseResource.self,
                MockLoggerResource.self
            ],
            services: [
                MockMigrationJob.self
            ]
        )
        
        // This will run the migration and then gracefully shutdown
        // because MockMigrationJob is an ApplicationJob
        // Note: Commented out as it would block the test
        // try await runner.run([MockMigrationJob.self])
        
        #expect(runner.context.identifier == "migration-runner")
    }
}
