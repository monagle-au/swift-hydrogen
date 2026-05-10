// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-hydrogen",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Core Hydrogen — always available.
        .library(
            name: "Hydrogen",
            targets: ["Hydrogen"]
        ),
        // Opt-in via the `Postgres` package trait.
        .library(
            name: "HydrogenPostgres",
            targets: ["HydrogenPostgres"]
        ),
        // Opt-in via the `OTel` package trait.
        .library(
            name: "HydrogenOTel",
            targets: ["HydrogenOTel"]
        ),
    ],
    traits: [
        // Opt-in for consumers — the bare `Hydrogen` library has no transitive
        // postgres-nio or swift-otel dependency. Consumers add `traits: ["Postgres"]`
        // and/or `traits: ["OTel"]` on the package import to enable the matching
        // library product.
        .default(enabledTraits: []),
        .trait(
            name: "Postgres",
            description: "Enable the HydrogenPostgres target and the postgres-nio dependency."
        ),
        .trait(
            name: "OTel",
            description: "Enable the HydrogenOTel target and the swift-otel dependency."
        ),
    ],
    dependencies: [
        // Core Hydrogen — always resolved.
        .package(url: "https://github.com/apple/swift-configuration", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.2.1"),

        // Postgres — used only by the HydrogenPostgres target. Resolved
        // unconditionally (SwiftPM resolves the full dependency graph), but the
        // product is only linked into HydrogenPostgres when the `Postgres` trait
        // is enabled, so consumers without the trait don't pull it into their
        // binary.
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.27.0"),

        // OTel — used only by the HydrogenOTel target. Same pattern as
        // postgres-nio: resolved at the package level, conditionally linked
        // by trait.
        .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0"),
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "Hydrogen",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "Instrumentation", package: "swift-distributed-tracing"),
            ]
        ),

        // MARK: - HydrogenPostgres (Postgres trait)
        .target(
            name: "HydrogenPostgres",
            dependencies: [
                "Hydrogen",
                .product(
                    name: "PostgresNIO",
                    package: "postgres-nio",
                    condition: .when(traits: ["Postgres"])
                ),
                .product(
                    name: "ServiceContextModule",
                    package: "swift-service-context",
                    condition: .when(traits: ["Postgres"])
                ),
            ],
            swiftSettings: [
                .define("HYDROGEN_POSTGRES", .when(traits: ["Postgres"])),
            ]
        ),

        // MARK: - HydrogenOTel (OTel trait)
        .target(
            name: "HydrogenOTel",
            dependencies: [
                "Hydrogen",
                .product(
                    name: "OTel",
                    package: "swift-otel",
                    condition: .when(traits: ["OTel"])
                ),
            ],
            swiftSettings: [
                .define("HYDROGEN_OTEL", .when(traits: ["OTel"])),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "HydrogenTests",
            dependencies: ["Hydrogen"]
        ),
        .testTarget(
            name: "HydrogenPostgresTests",
            dependencies: [
                "HydrogenPostgres",
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            swiftSettings: [
                .define("HYDROGEN_POSTGRES", .when(traits: ["Postgres"])),
            ]
        ),
        .testTarget(
            name: "HydrogenOTelTests",
            dependencies: [
                "HydrogenOTel",
            ],
            swiftSettings: [
                .define("HYDROGEN_OTEL", .when(traits: ["OTel"])),
            ]
        ),
    ]
)
