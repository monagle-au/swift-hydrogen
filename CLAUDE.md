# swift-hydrogen

A Swift server-side application framework built on top of swift-service-lifecycle, swift-argument-parser, and the swift-service-context ecosystem.

## Build & Test

```bash
swift build
swift test
```

Requires Swift 6.2+, macOS 15+.

## Architecture

### Key Protocols

**`HydrogenApplication`** — the `@main` entry point. Declares an `identifier`, a `configure(_:)` method to register services, and a `RootCommand` associated type (an `AsyncParsableCommand`) that serves as the CLI root.

**`HydrogenCommand`** — base protocol for all commands. Declares `requiredServices` (the service keys needed at runtime) and provides a default `run()` that builds services and drives the `ServiceGroup`. Two sub-protocols:
- `PersistentCommand` — runs services until the process receives a signal (e.g. HTTP server). No `execute` needed.
- `TaskCommand` — runs to completion then shuts the group down (e.g. migrations). Requires `execute(with:)`.

**`ServiceKey`** — SwiftUI `EnvironmentKey`-inspired key for type-safe service lookup. Define one per service type.

**`ServiceEntry` / `ConcreteServiceEntry<K>`** — wraps the build closure and lifecycle metadata for a service.

**`ServiceRegistry`** — ordered map of `ServiceKey` → `ServiceEntry`. Populated in `configure(_:)`.

**`ServiceValues`** — value-type container of resolved service instances, keyed by `ServiceKey`.

**`ApplicationRunner`** — internal orchestrator. Performs topological sort of required services, validates lifecycle constraints (persistent cannot depend on task), builds services in order, then runs a `ServiceGroup`.

### Adding a Service

1. Define a `ServiceKey`:
```swift
struct MyServiceKey: ServiceKey {
    static var defaultValue: MyService? { nil }
}
```

2. Register it in `configure(_:)`:
```swift
services.register(MyServiceKey.self, entry: ConcreteServiceEntry<MyServiceKey>(
    label: "my-service",
    mode: .persistent
) { values, config, logger in
    let svc = MyService(...)
    return (value: svc, service: svc)
})
```

3. Optionally add a convenience accessor on `ServiceValues`:
```swift
extension ServiceValues {
    var myService: MyService? { self[MyServiceKey.self] }
}
```

### Writing a Command

Single-command app (set `RootCommand` directly):
```swift
@main
struct MyApp: HydrogenApplication {
    typealias RootCommand = ServeCommand
    static let identifier = "my-app"
    static func configure(_ services: inout ServiceRegistry) { ... }
}

struct ServeCommand: PersistentCommand {
    typealias App = MyApp
    static let configuration = CommandConfiguration(abstract: "Run the server")
    var requiredServices: [any ServiceKey.Type] { [MyServiceKey.self] }
}
```

Multi-command app (compose with `CommandConfiguration`):
```swift
struct AppCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        subcommands: [ServeCommand.self, MigrateCommand.self],
        defaultSubcommand: ServeCommand.self
    )
}

@main
struct MyApp: HydrogenApplication {
    typealias RootCommand = AppCommand
    static let identifier = "my-app"
    static func configure(_ services: inout ServiceRegistry) { ... }
}
```

Commands are plain `AsyncParsableCommand` conformances — use `@Option`, `@Flag`, `@Argument` freely.

## Concurrency

The codebase targets Swift 6 strict concurrency. All public types are `Sendable`. `UncheckedSendableBox` is used in `HydrogenCommand` to bridge a non-`Sendable` command self into a `@Sendable` closure — this is safe because the execute closure runs sequentially after service setup on a single task.

## Testing

Tests use Swift Testing (`@Suite`, `@Test`, `#expect`). `ApplicationRunner` is internal but accessible via `@testable import Hydrogen`. Integration tests use `makeRunner(registry:)` helper and `QuickService` (no-op `Service` that waits for graceful shutdown).
