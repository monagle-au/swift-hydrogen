# ``HydrogenOTel``

OpenTelemetry integration for Hydrogen via
[`swift-otel`](https://github.com/swift-otel/swift-otel).

## Overview

`HydrogenOTel` is opt-in: enable the `OTel` package trait to bring
`swift-otel` into the dependency graph. The target adds:

- A bootstrap factory ``HydrogenOTel/makeBootstrap(serviceName:tracing:metrics:logsEnabled:configure:)``
  that wraps `swift-otel`'s `OTel.bootstrap(...)` and returns a
  ``BootstrapPlan`` ready to feed into
  ``HydrogenCommand/bootstrap(config:environment:)``.
- Opinionated CLI option groups (``OTelTracingOptions``,
  ``OTelMetricsOptions``) covering the most-used OTel knobs.
- Coordination with ``BootstrapCoordinator`` so swift-otel's
  internal one-shot installs of `LoggingSystem` /
  `MetricsSystem` / `InstrumentationSystem` don't conflict with
  any other bootstrap path.

## Topics

### Walkthrough

- <doc:OTelWalkthrough>

### Bootstrap

- ``HydrogenOTel``
- ``HydrogenOTel/makeBootstrap(serviceName:tracing:metrics:logsEnabled:configure:)``

### CLI option groups

- ``OTelTracingOptions``
- ``OTelMetricsOptions``
