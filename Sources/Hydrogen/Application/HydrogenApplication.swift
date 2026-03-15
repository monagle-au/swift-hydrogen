//
//  HydrogenApplication.swift
//  swift-hydrogen
//

import ArgumentParser

/// The main entry point protocol for a Hydrogen application.
///
/// Conform to this protocol to define your application's identity,
/// service configuration, and available commands in a single place.
/// Mark the conforming type with `@main` to make it the program entry point.
///
/// ```swift
/// @main
/// struct MyApp: HydrogenApplication {
///     static let identifier = "my-app"
///
///     static var commands: [any AsyncParsableCommand.Type] {
///         [ServeCommand.self, MigrateCommand.self]
///     }
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

    /// The subcommands available in this application.
    ///
    /// Each type must conform to ``AsyncParsableCommand``. Hydrogen commands
    /// should additionally conform to ``HydrogenCommand`` (or its refinements
    /// ``PersistentCommand`` / ``TaskCommand``) to gain automatic service
    /// lifecycle management.
    static var commands: [any AsyncParsableCommand.Type] { get }

    /// The default subcommand to run when no subcommand is specified.
    ///
    /// Defaults to `nil`, which causes ArgumentParser to print help.
    static var defaultCommand: (any AsyncParsableCommand.Type)? { get }
}

extension HydrogenApplication {
    /// Default implementation — no default subcommand (prints help).
    public static var defaultCommand: (any AsyncParsableCommand.Type)? { nil }

    /// Entry point called by `@main`.
    ///
    /// Delegates to ``_HydrogenRootCommand`` which wires `commands` into
    /// ArgumentParser's subcommand machinery.
    public static func main() async {
        await _HydrogenRootCommand<Self>.main()
    }
}
