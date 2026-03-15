//
//  ApplicationRunnerTests.swift
//  swift-hydrogen
//
//  Tests for ApplicationRunner: dependency resolution, lifecycle modes, and error cases.
//

import Testing
import ServiceLifecycle
import Logging
import Configuration
@testable import Hydrogen

// MARK: - Service Keys

private struct AKey: ServiceKey {
    static var defaultValue: String { "" }
}

private struct BKey: ServiceKey {
    static var defaultValue: String { "" }
}

private struct CKey: ServiceKey {
    static var defaultValue: String { "" }
}

// MARK: - Mock Services

/// A minimal no-op service that waits for graceful shutdown.
private struct QuickService: Service, Sendable {
    func run() async throws {
        try await gracefulShutdown()
    }
}

// MARK: - Helpers

private func makeRunner(
    registry: ServiceRegistry,
    identifier: String = "test-app"
) -> ApplicationRunner {
    ApplicationRunner(
        identifier: identifier,
        registry: registry,
        config: ConfigReader(provider: EnvironmentVariablesProvider()),
        environment: .testing,
        logger: Logger(label: identifier)
    )
}

// MARK: - ApplicationRunner Tests

@Suite("ApplicationRunner")
struct ApplicationRunnerTests {

    // MARK: Task mode — execute closure runs and shuts down

    @Test("Task mode: execute closure is called and group shuts down on completion")
    func taskModeExecuteClosureRuns() async throws {
        var registry = ServiceRegistry()
        registry.register(
            AKey.self,
            entry: ConcreteServiceEntry<AKey>(label: "a", mode: .task) { _, _, _ in
                (value: "a-value", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)

        // nonisolated(unsafe) is safe here: the execute closure runs sequentially
        // after all services are built, on a single task.
        nonisolated(unsafe) var executedWithValue: String = ""
        try await runner.run(
            requiredServices: [AKey.self],
            mode: .task,
            execute: { services in
                executedWithValue = services[AKey.self]
            }
        )
        #expect(executedWithValue == "a-value")
    }

    @Test("Task mode with no required services: execute closure still runs")
    func taskModeNoRequiredServices() async throws {
        let registry = ServiceRegistry()
        let runner = makeRunner(registry: registry)

        nonisolated(unsafe) var didExecute = false
        try await runner.run(
            requiredServices: [],
            mode: .task,
            execute: { _ in
                didExecute = true
            }
        )
        #expect(didExecute == true)
    }

    @Test("Task mode: service value is available in execute closure")
    func taskModeServiceValueAvailable() async throws {
        var registry = ServiceRegistry()
        registry.register(
            BKey.self,
            entry: ConcreteServiceEntry<BKey>(label: "b", mode: .task) { _, _, _ in
                (value: "built-b", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        nonisolated(unsafe) var gotValue: String = ""

        try await runner.run(
            requiredServices: [BKey.self],
            mode: .task,
            execute: { services in
                gotValue = services[BKey.self]
            }
        )
        #expect(gotValue == "built-b")
    }

    // MARK: Dependency resolution

    @Test("Dependency resolution: B is built before A when A depends on B")
    func dependencyResolutionOrder() async throws {
        // Build order tracking: the build closures are called synchronously and
        // sequentially by the runner, so this nonisolated(unsafe) access is safe.
        nonisolated(unsafe) var buildOrder: [String] = []

        var registry = ServiceRegistry()
        // B has no dependencies
        registry.register(
            BKey.self,
            entry: ConcreteServiceEntry<BKey>(label: "b", mode: .task) { _, _, _ in
                buildOrder.append("b")
                return (value: "b-value", service: QuickService())
            }
        )
        // A depends on B
        registry.register(
            AKey.self,
            entry: ConcreteServiceEntry<AKey>(
                label: "a",
                mode: .task,
                dependencies: [BKey.self]
            ) { _, _, _ in
                buildOrder.append("a")
                return (value: "a-value", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        try await runner.run(requiredServices: [AKey.self], mode: .task, execute: { _ in })
        // B must appear before A in the build order
        let bIndex = try #require(buildOrder.firstIndex(of: "b"))
        let aIndex = try #require(buildOrder.firstIndex(of: "a"))
        #expect(bIndex < aIndex)
    }

    @Test("Shared dependency is built only once")
    func sharedDependencyBuiltOnce() async throws {
        nonisolated(unsafe) var buildCount = 0

        var registry = ServiceRegistry()
        // C is a shared dependency of both A and B
        registry.register(
            CKey.self,
            entry: ConcreteServiceEntry<CKey>(label: "c", mode: .task) { _, _, _ in
                buildCount += 1
                return (value: "c-value", service: QuickService())
            }
        )
        registry.register(
            AKey.self,
            entry: ConcreteServiceEntry<AKey>(
                label: "a",
                mode: .task,
                dependencies: [CKey.self]
            ) { _, _, _ in
                return (value: "a-value", service: QuickService())
            }
        )
        registry.register(
            BKey.self,
            entry: ConcreteServiceEntry<BKey>(
                label: "b",
                mode: .task,
                dependencies: [CKey.self]
            ) { _, _, _ in
                return (value: "b-value", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        try await runner.run(
            requiredServices: [AKey.self, BKey.self],
            mode: .task,
            execute: { _ in }
        )
        #expect(buildCount == 1)
    }

    // MARK: Error cases

    @Test("Missing service throws ApplicationError.missingService")
    func missingServiceThrows() async throws {
        // Register nothing for AKey but require it
        let registry = ServiceRegistry()
        let runner = makeRunner(registry: registry)

        await #expect(throws: ApplicationError.self) {
            try await runner.run(requiredServices: [AKey.self], mode: .task, execute: nil)
        }
    }

    @Test("Missing service error has missingService case")
    func missingServiceErrorCase() async throws {
        let registry = ServiceRegistry()
        let runner = makeRunner(registry: registry)

        do {
            try await runner.run(requiredServices: [AKey.self], mode: .task, execute: nil)
            Issue.record("Expected ApplicationError.missingService to be thrown")
        } catch let error as ApplicationError {
            if case .missingService = error {
                // Expected
            } else {
                Issue.record("Expected .missingService but got: \(error)")
            }
        }
    }

    @Test("Cyclic dependency throws ApplicationError.cyclicDependency")
    func cyclicDependencyThrows() async throws {
        var registry = ServiceRegistry()
        // A depends on B, B depends on A — a cycle
        registry.register(
            AKey.self,
            entry: ConcreteServiceEntry<AKey>(
                label: "a",
                mode: .persistent,
                dependencies: [BKey.self]
            ) { _, _, _ in
                (value: "a", service: QuickService())
            }
        )
        registry.register(
            BKey.self,
            entry: ConcreteServiceEntry<BKey>(
                label: "b",
                mode: .persistent,
                dependencies: [AKey.self]
            ) { _, _, _ in
                (value: "b", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        do {
            try await runner.run(requiredServices: [AKey.self], mode: .task, execute: nil)
            Issue.record("Expected ApplicationError.cyclicDependency to be thrown")
        } catch let error as ApplicationError {
            if case .cyclicDependency = error {
                // Expected
            } else {
                Issue.record("Expected .cyclicDependency but got: \(error)")
            }
        }
    }

    @Test("Persistent service depending on task service throws ApplicationError.persistentDependsOnTask")
    func persistentDependsOnTaskThrows() async throws {
        var registry = ServiceRegistry()
        // B is task-scoped
        registry.register(
            BKey.self,
            entry: ConcreteServiceEntry<BKey>(label: "b", mode: .task) { _, _, _ in
                (value: "b", service: QuickService())
            }
        )
        // A is persistent but depends on task-scoped B
        registry.register(
            AKey.self,
            entry: ConcreteServiceEntry<AKey>(
                label: "a",
                mode: .persistent,
                dependencies: [BKey.self]
            ) { _, _, _ in
                (value: "a", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        do {
            try await runner.run(requiredServices: [AKey.self], mode: .task, execute: nil)
            Issue.record("Expected ApplicationError.persistentDependsOnTask to be thrown")
        } catch let error as ApplicationError {
            if case .persistentDependsOnTask(let persistent, let task) = error {
                #expect(persistent == "a")
                #expect(task == "b")
            } else {
                Issue.record("Expected .persistentDependsOnTask but got: \(error)")
            }
        }
    }

    // MARK: ApplicationError description

    @Test("ApplicationError descriptions contain relevant names")
    func applicationErrorDescriptions() {
        let missing = ApplicationError.missingService(key: "MyKey")
        #expect(missing.description.contains("MyKey"))

        let cyclic = ApplicationError.cyclicDependency(path: ["a", "b", "a"])
        #expect(cyclic.description.contains("a"))
        #expect(cyclic.description.contains("b"))

        let persOnTask = ApplicationError.persistentDependsOnTask(
            persistent: "persistentSvc",
            task: "taskSvc"
        )
        #expect(persOnTask.description.contains("persistentSvc"))
        #expect(persOnTask.description.contains("taskSvc"))

        let missingConfig = ApplicationError.missingConfiguration(
            key: "db.host",
            service: "postgres"
        )
        #expect(missingConfig.description.contains("db.host"))
        #expect(missingConfig.description.contains("postgres"))
    }
}

// MARK: - Integration Tests

@Suite("ApplicationRunner Integration")
struct ApplicationRunnerIntegrationTests {

    /// Full flow: define ServiceKeys, build entries, register them, run with a task execute closure.
    @Test("Full integration: keys → entries → registry → runner → task execute")
    func fullIntegrationFlow() async throws {
        struct GreeterKey: ServiceKey {
            static var defaultValue: String { "" }
        }

        var registry = ServiceRegistry()
        registry.register(
            GreeterKey.self,
            entry: ConcreteServiceEntry<GreeterKey>(
                label: "greeter",
                mode: .task
            ) { _, _, _ in
                (value: "Hello, World!", service: QuickService())
            }
        )

        let runner = ApplicationRunner(
            identifier: "integration-app",
            registry: registry,
            config: ConfigReader(provider: EnvironmentVariablesProvider()),
            environment: .testing,
            logger: Logger(label: "integration-app")
        )

        nonisolated(unsafe) var result: String = ""
        try await runner.run(
            requiredServices: [GreeterKey.self],
            mode: .task,
            execute: { services in
                result = services[GreeterKey.self]
            }
        )
        #expect(result == "Hello, World!")
    }

    /// HydrogenApplication conformance wires up correctly.
    @Test("HydrogenApplication conformance: configure populates registry")
    func hydrogenApplicationConformance() {
        struct CountKey: ServiceKey {
            static var defaultValue: Int { -1 }
        }

        struct NopCommand: AsyncParsableCommand {}

        struct TestApp: HydrogenApplication {
            typealias RootCommand = NopCommand
            static let identifier = "test-app"

            static func configure(_ services: inout ServiceRegistry) {
                services.register(
                    CountKey.self,
                    entry: ConcreteServiceEntry<CountKey>(label: "counter", mode: .persistent) { _, _, _ in
                        (value: 42, service: QuickService())
                    }
                )
            }
        }

        var registry = ServiceRegistry()
        TestApp.configure(&registry)

        #expect(registry.entries.count == 1)
        #expect(registry.entries.first?.entry.label == "counter")
    }

    /// A chain of three services: X ← Y ← Z. All three are built in correct order.
    @Test("Three-level dependency chain resolves in correct order")
    func threeLevelDependencyChain() async throws {
        struct X: ServiceKey { static var defaultValue: Int { 0 } }
        struct Y: ServiceKey { static var defaultValue: Int { 0 } }
        struct Z: ServiceKey { static var defaultValue: Int { 0 } }

        nonisolated(unsafe) var buildOrder: [String] = []

        var registry = ServiceRegistry()
        registry.register(
            X.self,
            entry: ConcreteServiceEntry<X>(label: "x", mode: .task) { _, _, _ in
                buildOrder.append("x")
                return (value: 1, service: QuickService())
            }
        )
        registry.register(
            Y.self,
            entry: ConcreteServiceEntry<Y>(
                label: "y",
                mode: .task,
                dependencies: [X.self]
            ) { _, _, _ in
                buildOrder.append("y")
                return (value: 2, service: QuickService())
            }
        )
        registry.register(
            Z.self,
            entry: ConcreteServiceEntry<Z>(
                label: "z",
                mode: .task,
                dependencies: [Y.self]
            ) { _, _, _ in
                buildOrder.append("z")
                return (value: 3, service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        try await runner.run(requiredServices: [Z.self], mode: .task, execute: { _ in })

        let xIdx = try #require(buildOrder.firstIndex(of: "x"))
        let yIdx = try #require(buildOrder.firstIndex(of: "y"))
        let zIdx = try #require(buildOrder.firstIndex(of: "z"))
        #expect(xIdx < yIdx)
        #expect(yIdx < zIdx)
    }

    /// Values produced by dependencies are visible to downstream services.
    @Test("Downstream service can read value set by upstream service")
    func downstreamReadsUpstreamValue() async throws {
        struct UpKey: ServiceKey { static var defaultValue: Int { 0 } }
        struct DownKey: ServiceKey { static var defaultValue: String { "" } }

        var registry = ServiceRegistry()
        registry.register(
            UpKey.self,
            entry: ConcreteServiceEntry<UpKey>(label: "upstream", mode: .task) { _, _, _ in
                (value: 100, service: QuickService())
            }
        )
        registry.register(
            DownKey.self,
            entry: ConcreteServiceEntry<DownKey>(
                label: "downstream",
                mode: .task,
                dependencies: [UpKey.self]
            ) { values, _, _ in
                let upValue = values[UpKey.self]
                return (value: "saw \(upValue)", service: QuickService())
            }
        )

        let runner = makeRunner(registry: registry)
        nonisolated(unsafe) var result = ""
        try await runner.run(
            requiredServices: [DownKey.self],
            mode: .task,
            execute: { services in
                result = services[DownKey.self]
            }
        )
        #expect(result == "saw 100")
    }
}
