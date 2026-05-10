# Hydrogen

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2015+-blue.svg)](https://swift.org)

**Hydrogen** is a small server-side Swift framework that ties together
the SSWG ecosystem (`swift-service-lifecycle`, `swift-argument-parser`,
`swift-service-context`, `swift-log`, `swift-metrics`,
`swift-distributed-tracing`, `swift-configuration`) into a single
ergonomic harness for building CLI-driven services. It abstracts away
the boilerplate of the bootstrap dance — installing the global
logging/metrics/tracing systems in the right order, after CLI parsing,
before any service is built — without taking power away from the
underlying libraries.

Hydrogen is structured for both long-running services (HTTP servers,
queue workers) and one-shot tasks (migrations, backfills) sharing the
same service registry and configuration story.

---

## Features

- **Declarative service graph**. Services are registered by typed
  `ServiceKey`, declare their dependencies, and Hydrogen
  topologically sorts them before handing them to a `ServiceGroup`.
- **Two command shapes**: `PersistentCommand` (services run until
  signalled) and `TaskCommand` (services come up, the command does
  its work, the group shuts down gracefully).
- **Bootstrap pipeline**. `HydrogenCommand.bootstrap(...)` returns a
  `BootstrapPlan` that the framework applies through
  `BootstrapCoordinator` — globals install in tracing → metrics →
  logging order, after CLI flags are parsed, before the first
  `Logger` is built.
- **Vendor-neutral structured logging** via `StructuredLogHandler`
  driven by an extensible `StructuredLogProfile`.
- **CLI option groups** for common observability flags
  (`LoggingOptions`, `TracingOptions`, `MetricsOptions`).
- **Trait-gated optional integrations**: every cloud-vendor or
  ecosystem dependency is opt-in via a Swift Package trait, so apps
  pay nothing for what they don't use.

## Requirements

- Swift 6.2+
- macOS 15+

## Installation

Add Hydrogen to `Package.swift`:

```swift
.package(url: "https://github.com/<org>/swift-hydrogen.git", from: "1.0.0"),
```

By default, only the core `Hydrogen` library is resolved. Optional
integrations are enabled per-consumer via package traits — add only
the ones you need:

```swift
.package(
    url: "https://github.com/<org>/swift-hydrogen.git",
    from: "1.0.0",
    traits: ["Postgres", "OTel", "GCP"]
),
```

| Trait      | Library product   | Adds                                                     |
|------------|-------------------|----------------------------------------------------------|
| (none)     | `Hydrogen`        | Core framework, always available.                        |
| `Postgres` | `HydrogenPostgres`| `PostgresNIO`-backed service key, configuration, migrations. |
| `OTel`     | `HydrogenOTel`    | `swift-otel` integration: `BootstrapPlan` factory + CLI flags. |
| `GCP`      | `HydrogenGCP`     | Cloud Trace tracer/exporter + Cloud Logging `LogHandler`. |

Then depend on each library product in the targets that need it:

```swift
.executableTarget(
    name: "MyService",
    dependencies: [
        .product(name: "Hydrogen", package: "swift-hydrogen"),
        .product(name: "HydrogenPostgres", package: "swift-hydrogen"),
        .product(name: "HydrogenOTel", package: "swift-hydrogen"),
    ]
),
```

## At a glance

```swift
import Hydrogen
import HydrogenPostgres

@main
struct MyApp: HydrogenApplication {
    typealias RootCommand = AppCommand
    static let identifier = "my-app"

    static func configure(_ services: inout ServiceRegistry) {
        services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
    }
}

struct AppCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        subcommands: [Serve.self, Migrate.self],
        defaultSubcommand: Serve.self
    )
}

struct Serve: PersistentCommand {
    typealias App = MyApp
    static let configuration = CommandConfiguration(abstract: "Run the server")

    @OptionGroup var logging: LoggingOptions
    @OptionGroup var tracing: TracingOptions

    var requiredServices: [any ServiceKey.Type] { [PostgresServiceKey.self] }

    func bootstrap(config: ConfigReader, environment: Environment) -> BootstrapPlan {
        var plan = BootstrapPlan()
        plan.logLevel = logging.resolvedLogLevel
        plan.logHandlerFactory = logging.format.factory(default: HydrogenLogging.cloudRunOrStream.asFactory)
        return plan
    }
}

struct Migrate: TaskCommand {
    typealias App = MyApp
    static let configuration = CommandConfiguration(abstract: "Run database migrations")
    var requiredServices: [any ServiceKey.Type] { [PostgresServiceKey.self] }

    func execute(with services: ServiceValues) async throws {
        try await PostgresMigrator.migrate(
            myMigrations,
            on: services.postgres!,
            logger: ServiceContext.active.logger ?? Logger(label: "migrate")
        )
    }
}
```

## Documentation

Full DocC documentation lives alongside each module:

- [`Hydrogen`](Sources/Hydrogen/Hydrogen.docc/) — getting started,
  key concepts, local + cloud deployment guides.
- [`HydrogenPostgres`](Sources/HydrogenPostgres/HydrogenPostgres.docc/)
  — Postgres walkthrough.
- [`HydrogenOTel`](Sources/HydrogenOTel/HydrogenOTel.docc/) — OTel
  walkthrough.
- [`HydrogenGCP`](Sources/HydrogenGCP/HydrogenGCP.docc/) — Cloud
  Trace + Cloud Logging walkthrough.

Build the docs locally with the
[Swift DocC Plugin](https://github.com/swiftlang/swift-docc-plugin):

```bash
swift package --traits Postgres,OTel,GCP \
    generate-documentation --target Hydrogen
```

## Testing

```bash
swift test                                 # core only
swift test --traits Postgres,OTel,GCP      # everything
```

The test suite covers dependency resolution, lifecycle modes,
bootstrap ordering, structured logging, CLI option parsing, and the
optional integrations.

## License

See [LICENSE](LICENSE).
