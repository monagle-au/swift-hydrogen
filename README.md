# Hydrogen

A lightweight Swift toolkit for building server-side apps on Apple platforms with a focus on:
- Consistent logging and context propagation (ServiceContext).
- Clear environment configuration.
- Ergonomic PostgresNIO helpers for queries and data binding.
- Small async utilities.

This code favors Swift Concurrency, swift-log, and PostgresNIO.

## Features

- ServiceContext extensions
  - ServiceContext.active: Safe access to the current context with a `.topLevel` fallback.
  - ServiceContext.logger: Strictly-enforced contextual Logger with a clear precondition on misuse.
  - ServiceContext.environment: Strictly-enforced Environment with a clear precondition on misuse.

- Environment management
  - Environment: A Sendable, Equatable value representing deployment environment (development, testing, production).
  - CLI parsing via ArgumentParser (Environment.Arguments).
  - Helpers for reading process environment variables and suffixing strings.

- Logging helpers
  - Logger.MetadataValue.custom / describe: Convert arbitrary values into metadata strings.

- Async utilities
  - AsyncSequence.first(): A convenience to get the first element of an async sequence.

- PostgresNIO helpers
  - PostgresData.optional(...): Map optional Swift values to PostgresData or .null.
  - PostgresQuery.multiValueRowQuery: Build multi-row VALUES SQL with correct placeholders and bindings.
  - PGReflectedError: Wrap and reflect PostgresNIO errors (PSQLError, PostgresDecodingError).
  - logUnwrappedPostgreSQLErrors: Debug-only wrappers to log reflected Postgres errors around sync/async operations.

## Installation

This project is a Swift Package. Add it to your Package.swift:
