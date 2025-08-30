//
//  Postgres+Config.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 17/9/2024.
//

import Hydrogen
import PostgresNIO

extension PostgresClient.Configuration {
    public init(name: String, for environment: Environment) {
        let database = environment.addSuffix(name)
        self.init(host: "localhost", port: 5432, username: "postgres", password: nil, database: database, tls: .disable)
    }
}

extension PostgresClient {
//    public static func createFromContext(name: String) -> PostgresClient {
//        let context = ServiceContext.current!
//        let pgConfig = PostgresClient.Configuration(name: name, for: context.environment)
//        return PostgresClient(configuration: pgConfig, backgroundLogger: context.logger)
//    }
//    
//    public convenience init(name: String, environment: Environment, logger: Logger) {
//        let pgConfig = PostgresClient.Configuration(name: name, for: environment)
//        self.init(configuration: pgConfig, backgroundLogger: logger)
//    }
//    
//    public func serviceConfiguration() -> ServiceGroupConfiguration.ServiceConfiguration {
//        ServiceGroupConfiguration.ServiceConfiguration(service: self)
//    }
}
