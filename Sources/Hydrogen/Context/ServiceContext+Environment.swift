//
//  ServiceContext+Environment.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 3/9/2024.
//

import ServiceContextModule

private enum EnvironmentContextKey: ServiceContextKey {
    typealias Value = Environment
}

extension ServiceContext {
    /// The `Environment` associated with this `ServiceContext`.
    ///
    /// - Setter: Stores the provided `Environment` in the context under a private key.
    /// - Getter (strict): Returns the previously configured `Environment`. If none has
    ///   been set on this context, the getter triggers a `preconditionFailure` with
    ///   guidance on how to configure one. This strict behavior mirrors the `logger`
    ///   accessor to surface configuration mistakes early during development and testing.
    ///
    /// Example:
    ///   var context = ServiceContext.topLevel
    ///   context.environment = .production
    ///   // later
    ///   let env = context.environment
    public var environment: Environment {
        set {
            self[EnvironmentContextKey.self] = newValue
        }
        get {
            guard let environment = self[EnvironmentContextKey.self] else {
                preconditionFailure(
                    """
                    ServiceContext.environment not configured.
                    Ensure an Environment is set on the ServiceContext before use, e.g.:

                        var context = ServiceContext.topLevel
                        context.environment = .development // or .staging / .production

                    """
                )
            }
            return environment
        }
    }
}
