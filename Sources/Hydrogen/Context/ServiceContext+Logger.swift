//
//  ServiceContext+Logger.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 28/8/2024.
//

import ServiceContextModule
import Logging

private enum LoggerKey: ServiceContextKey {
    typealias Value = Logger
}

extension ServiceContext {
    /// A `Logger` associated with this `ServiceContext`.
    ///
    /// - Setter: Stores the provided `Logger` in the context under a private key.
    /// - Getter (strict): Returns the previously configured `Logger`. If no logger
    ///   has been set on this context, the getter triggers a `preconditionFailure`
    ///   with guidance on how to configure one. This is intentionally strict to
    ///   catch configuration errors early during development and testing.
    ///
    /// Usage:
    ///   var context = ServiceContext.topLevel
    ///   context.logger = Logger(label: "com.example.app")
    ///   context.logger.info("Ready")
    ///
    /// If you need a more lenient pattern (e.g., optional or defaulted logger),
    /// consider adding a separate accessor rather than weakening this strict contract.
    public var logger: Logger {
        set {
            self[LoggerKey.self] = newValue
        }
        get {
            guard let logger = self[LoggerKey.self] else {
                preconditionFailure(
                    """
                    ServiceContext.logger not configured.
                    Ensure a Logger is set on the ServiceContext before use, e.g.:

                        var context = ServiceContext.topLevel
                        context.logger = Logger(label: "your.label")
                        // or inject via middleware/task setup

                    """
                )
            }
            return logger
        }
    }
}
