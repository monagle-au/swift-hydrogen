//
//  HydrogenApplication.swift
//  swift-hydrogen
//

import ArgumentParser

/// The main entry point protocol for a Hydrogen application.
///
/// Conform to this protocol to define your application's identity,
/// service configuration, and root CLI command in a single place.
/// Mark the conforming type with `@main` to make it the program entry point.
///
/// For a single-command application, set `RootCommand` directly to a
/// ``HydrogenCommand`` conformance:
///
/// ```swift
/// @main
/// struct MyApp: HydrogenApplication {
///     typealias RootCommand = ServeCommand
///     static let identifier = "my-app"
///
///     static func configure(_ services: inout ServiceRegistry) {
///         services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
///     }
/// }
/// ```
///
/// For multiple commands, declare a plain `AsyncParsableCommand` as your root
/// and use ArgumentParser's `CommandConfiguration` normally:
///
/// ```swift
/// struct AppCommand: AsyncParsableCommand {
///     static var configuration = CommandConfiguration(
///         subcommands: [ServeCommand.self, MigrateCommand.self],
///         defaultSubcommand: ServeCommand.self
///     )
/// }
///
/// @main
/// struct MyApp: HydrogenApplication {
///     typealias RootCommand = AppCommand
///     static let identifier = "my-app"
///
///     static func configure(_ services: inout ServiceRegistry) {
///         services.register(PostgresServiceKey.self, entry: postgresServiceEntry())
///     }
/// }
/// ```
public protocol HydrogenApplication: Sendable {
    /// A unique identifier for this application.
    ///
    /// Used as the default logger label, tracing service name, and in
    /// diagnostic messages.
    static var identifier: String { get }

    /// Registers service entries into the provided ``ServiceRegistry``.
    ///
    /// This method is called once during startup, before any command runs.
    /// Add entries for every service your application may need across all commands.
    ///
    /// - Parameter services: The registry to populate.
    static func configure(_ services: inout ServiceRegistry)

    /// The root CLI command for this application.
    ///
    /// This type is the ArgumentParser entry point. For a single-command app,
    /// set this to a ``HydrogenCommand`` directly. For multiple commands, use
    /// a plain `AsyncParsableCommand` with `CommandConfiguration.subcommands`.
    associatedtype RootCommand: AsyncParsableCommand
}

extension HydrogenApplication {
    /// Entry point called by `@main`.
    ///
    /// Delegates directly to `RootCommand.main()`.
    public static func main() async {
        await RootCommand.main()
    }
}
