# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
from `1.0.0` onwards.

## [Unreleased]

## [1.0.0] — 2026-05-10

The first stable release. From this point on, public-API changes
follow strict SemVer.

### Added

- **Application & command harness** — ``HydrogenApplication``
  marks the `@main` entry point; ``HydrogenCommand`` builds on
  `AsyncParsableCommand` with the protocol surface the framework
  needs (`requiredServices`, `bootstrap(config:environment:)`,
  `execute(with:)`). ``PersistentCommand`` and ``TaskCommand``
  capture the two common shapes.
- **Typed service registry** — ``ServiceKey``, ``ServiceRegistry``,
  ``ServiceValues``, and ``ConcreteServiceEntry`` together provide a
  declarative dependency graph that ``ApplicationRunner``
  topologically sorts before handing services to a
  `ServiceLifecycle.ServiceGroup`. ``ServiceLifecycleMode``
  distinguishes persistent vs. task services; the runner enforces
  that persistent services may not depend on task services.
- **Bootstrap pipeline** — ``BootstrapPlan`` is a value-type
  description of what the global logging/metrics/tracing systems
  should install. ``BootstrapCoordinator`` applies plans
  per-subsystem-idempotently, in tracing → metrics → logging
  order, after CLI parsing and before any `Logger` is built.
  Static escape hatches
  (``HydrogenApplication/bootstrapLogging(using:metadataProvider:logLevel:)``,
  ``HydrogenApplication/bootstrapTracing(using:)``,
  ``HydrogenApplication/bootstrapMetrics(using:)``) all route
  through the same coordinator.
- **Lifecycle services in the plan** — ``LifecycleService`` lets
  bootstrap-related services (e.g. an OTel exporter) start
  alongside user services without being keyed in the registry.
- **Vendor-neutral structured logging** — ``StructuredLogHandler``
  emits JSON-per-line shaped by an extensible
  ``StructuredLogProfile``. The
  ``StructuredLogProfile/plain`` profile is the vendor-neutral
  default; vendor dialects (Cloud Logging, Datadog, ECS, …) extend
  the profile via `static let` factories.
- **CLI option groups for observability** — ``LoggingOptions``,
  ``TracingOptions``, ``MetricsOptions`` are reusable
  `ParsableArguments` types that compose into commands via
  `@OptionGroup`. Each carries a `merging(from: ConfigReader)`
  method so the same fields can be driven by env vars, `.env`
  files, or any other `ConfigProvider`. Precedence is
  CLI > config > built-in default.
- **`HydrogenPostgres` target** (gated by the `Postgres` package
  trait) — typed ``PostgresServiceKey`` and
  ``postgresServiceEntry()`` factory; configuration builder mapping
  a `ConfigReader` scope onto pool/timeout/TLS knobs;
  ``PostgresMigrator`` for transactional, idempotent migrations;
  optional-binding helpers and a multi-row INSERT helper;
  DEBUG-only `PGReflectableError` reflection.
- **`HydrogenOTel` target** (gated by the `OTel` package trait) —
  ``HydrogenOTel/makeBootstrap(serviceName:tracing:metrics:logsEnabled:configure:)``
  wraps swift-otel's `OTel.bootstrap(...)` and returns a
  ``BootstrapPlan``. Opinionated ``OTelTracingOptions`` and
  ``OTelMetricsOptions`` carry the most-used OTel knobs as CLI
  flags + ConfigReader merging.
- **`HydrogenGCP` target** (gated by the `GCP` package trait) —
  ``GCPLogHandler`` (Cloud Logging-shaped JSON, implemented as a
  thin wrapper over ``StructuredLogHandler`` with the
  ``StructuredLogProfile/gcp(projectID:)`` profile);
  ``GCPTracer`` / ``GCPSpan`` / ``CloudTraceExporter`` for Cloud
  Trace export with W3C Trace Context propagation;
  ``HydrogenApplication/bootstrapGCPTracing(projectID:)`` static
  helper; ``HydrogenGCP/cloudRunOrStream`` selector.
- **Trait split** — three opt-in package traits (`Postgres`,
  `OTel`, `GCP`) gate three optional library products. Consumers
  pay nothing for integrations they don't enable.
- **DocC documentation** — four catalogs (one per library
  product). The `Hydrogen` catalog contains *Getting Started*,
  *Key Concepts*, *Local Deployment*, and *Cloud Deployment*
  articles plus topics organised by area. Each optional target
  ships a walkthrough article. swift-docc-plugin is added so
  consumers can build docs locally with
  `swift package generate-documentation`.

### Migration from pre-1.0 main

The shape of the package changed substantially from any pre-1.0
usage that tracked `main` directly. If you depended on swift-hydrogen
before tagging:

- **Library product split.** The `Hydrogen` library product no
  longer bundles `HydrogenPostgres`. Add
  `traits: ["Postgres"]` to your package import and
  `import HydrogenPostgres` explicitly where the Postgres helpers
  are used. Same pattern for the new `OTel` and `GCP` traits.
- **`GCPLogHandler` moved.** The type is now in `HydrogenGCP`.
  Enable `traits: ["GCP"]` and `import HydrogenGCP`. The public
  initializers are unchanged; the implementation is a thin wrapper
  over ``StructuredLogHandler`` with the
  ``StructuredLogProfile/gcp(projectID:)`` profile.
- **`GCPTracer` / `GCPSpan` / `CloudTraceExporter` moved.** Same
  story: now in `HydrogenGCP`, enable the trait, update imports.
- **`HydrogenLogging.gcp` removed.** Use
  `HydrogenGCP.logHandlerFactory` (or
  ``HydrogenGCP/cloudRunOrStream``) after enabling the `GCP`
  trait.
- **`HydrogenLogging.cloudRunOrStream` defaults changed.** It now
  picks ``StructuredLogHandler`` with the
  ``StructuredLogProfile/plain`` profile when on Cloud Run / Cloud
  Run Jobs, instead of GCP-flavoured JSON. For Cloud Logging's
  magic-key dialect, switch to ``HydrogenGCP/cloudRunOrStream``.
- **`LoggingOptions.LogFormat.json` shape changed.** It now
  resolves to ``StructuredLogHandler`` with the `.plain` profile
  (vendor-neutral keys) rather than `GCPLogHandler`. The on-the-wire
  log line still parses as JSON but no longer carries
  `logging.googleapis.com/*` magic keys. Apps that need the GCP
  shape via `--log-format=json` should override
  ``BootstrapPlan/logHandlerFactory`` directly with
  ``HydrogenGCP/logHandlerFactory``.
- **Bootstrap convention shifted.** The "override `main()` and call
  `bootstrapLogging`/`bootstrapTracing`" pattern still works (the
  static methods are now escape hatches that route through
  ``BootstrapCoordinator``), but the recommended path is
  ``HydrogenCommand/bootstrap(config:environment:)`` returning a
  ``BootstrapPlan``, so CLI flags and ``ConfigReader`` values can
  drive the bootstrap.

### Requirements

- Swift 6.2+
- macOS 15+

[Unreleased]: https://github.com/monagle-au/swift-hydrogen/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/monagle-au/swift-hydrogen/releases/tag/v1.0.0
