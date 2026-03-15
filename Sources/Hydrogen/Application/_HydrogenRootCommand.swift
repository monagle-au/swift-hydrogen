//
//  _HydrogenRootCommand.swift
//  swift-hydrogen
//

import ArgumentParser

/// Internal root command that wires a ``HydrogenApplication``'s declared commands
/// into ArgumentParser's subcommand machinery.
///
/// This type is an implementation detail of the framework. End-users interact
/// with it only indirectly through ``HydrogenApplication/main()``.
///
/// The underscore prefix signals that this is a framework-internal type and is
/// not part of the public API surface.
public struct _HydrogenRootCommand<App: HydrogenApplication>: AsyncParsableCommand {
    /// ArgumentParser configuration derived at type-initialization time.
    ///
    /// `subcommands` is populated from ``HydrogenApplication/commands``.
    /// `defaultSubcommand` is set to ``HydrogenApplication/defaultCommand`` if provided.
    public static var configuration: CommandConfiguration {
        // AsyncParsableCommand.Type conforms to ParsableCommand.Type because
        // AsyncParsableCommand refines ParsableCommand.
        let subs: [ParsableCommand.Type] = App.commands.compactMap { $0 as? ParsableCommand.Type }
        let defaultSub: ParsableCommand.Type? = App.defaultCommand as? ParsableCommand.Type
        return CommandConfiguration(
            commandName: App.identifier,
            subcommands: subs,
            defaultSubcommand: defaultSub
        )
    }

    /// Required empty initializer for ArgumentParser conformance.
    public init() {}

    /// Runs the root command.
    ///
    /// For the root command itself, this is typically never called because
    /// ArgumentParser will dispatch to a subcommand. If invoked directly
    /// (when no default subcommand is set), it prints help and exits.
    public func run() async throws {
        // ArgumentParser handles printing help for the root command.
        throw CleanExit.helpRequest()
    }
}
