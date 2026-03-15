import Testing
@testable import Hydrogen

/// Smoke test: the module compiles and key public types are accessible.
@Suite("Hydrogen Smoke Tests")
struct HydrogenTests {

    @Test("ServiceValues is constructible")
    func serviceValuesConstructible() {
        let _ = ServiceValues()
    }

    @Test("ServiceRegistry is constructible")
    func serviceRegistryConstructible() {
        let _ = ServiceRegistry()
    }

    @Test("ServiceLifecycleMode cases are accessible")
    func lifecycleModeAccessible() {
        let persistent = ServiceLifecycleMode.persistent
        let task = ServiceLifecycleMode.task
        #expect(persistent != task)
    }

    @Test("ApplicationError is throwable and conforms to Error")
    func applicationErrorIsThrowable() {
        let error: any Error = ApplicationError.missingService(key: "SomeKey")
        #expect(error is ApplicationError)
    }

    @Test("Environment presets are defined")
    func environmentPresets() {
        #expect(Environment.development.name == "development")
        #expect(Environment.production.name == "production")
        #expect(Environment.testing.name == "testing")
    }
}
