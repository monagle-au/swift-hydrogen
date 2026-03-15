//
//  ApplicationError.swift
//  swift-hydrogen
//

/// Errors that can be thrown during Hydrogen application startup and service resolution.
public enum ApplicationError: Error, CustomStringConvertible, Sendable {
    /// A required service was not found in the ``ServiceRegistry``.
    ///
    /// This typically means ``HydrogenApplication/configure(_:)`` did not register
    /// an entry for a key type that a command listed in its `requiredServices`.
    case missingService(key: String)

    /// A cyclic dependency was detected in the service graph.
    ///
    /// The associated `path` describes the cycle: the last element depends on
    /// one of the earlier elements, forming a loop.
    case cyclicDependency(path: [String])

    /// A persistent service declares a dependency on a task-scoped service.
    ///
    /// This is invalid because a persistent service is expected to outlive the
    /// application's run, whereas a task service shuts down the group on completion.
    /// A persistent service cannot depend on something that will vanish mid-run.
    case persistentDependsOnTask(persistent: String, task: String)

    /// A required configuration key was absent or could not be parsed.
    ///
    /// - Parameters:
    ///   - key: The configuration key that was missing.
    ///   - service: The label of the service that required the configuration.
    case missingConfiguration(key: String, service: String)

    /// A human-readable description suitable for log output and error messages.
    public var description: String {
        switch self {
        case .missingService(let key):
            return "Missing service registration for key '\(key)'. " +
                   "Ensure you call services.register(\(key).self, entry: …) " +
                   "inside your App's configure(_:) method."

        case .cyclicDependency(let path):
            return "Cyclic service dependency detected: \(path.joined(separator: " → ")). " +
                   "Break the cycle by refactoring the dependency graph."

        case .persistentDependsOnTask(let persistent, let task):
            return "Persistent service '\(persistent)' depends on task service '\(task)', " +
                   "which is invalid. A persistent service is expected to run for the lifetime " +
                   "of the application, but a task service shuts down the group upon completion. " +
                   "Consider making '\(task)' persistent, or remove the dependency."

        case .missingConfiguration(let key, let service):
            return "Service '\(service)' requires configuration key '\(key)', " +
                   "but it was not found in any configuration provider."
        }
    }
}
