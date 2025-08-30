// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-hydrogen",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Hydrogen",
            targets: ["Hydrogen", "HydrogenPostgres"]
        ),
    ],
    dependencies: [
        // Hydrogen
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.2.1"),
        
        // Postgres
        .package(url: "https://github.com/monagle-au/uuid-kit", from: "1.0.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.27.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Hydrogen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "Metrics", package: "swift-metrics"),
            ]
        ),
        .target(
            name: "HydrogenPostgres",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "UUIDKit", package: "uuid-kit"),
            ]
        ),
        .testTarget(
            name: "HydrogenTests",
            dependencies: ["Hydrogen"]
        ),
    ]
)
