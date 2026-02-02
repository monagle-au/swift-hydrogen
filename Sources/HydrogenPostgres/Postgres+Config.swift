//
//  Postgres+Config.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 17/9/2024.
//

import Configuration
import NIOSSL
import PostgresNIO

extension PostgresClient.Configuration {
    public init(config: ConfigReader) {
        let username = config.string(forKey: "username", default: "postgres")
        let password = config.string(forKey: "password", isSecret: true)
        let database = config.string(forKey: "database")

        if let unixSocketPath = config.string(forKey: "unixSocketPath") {
            self.init(
                unixSocketPath: unixSocketPath, username: username, password: password,
                database: database)
        } else {
            let host = config.string(forKey: "host", default: "localhost")
            let port = config.int(forKey: "port", default: 5432)
            let tls = PostgresClient.Configuration.TLS(config: config)

            self.init(
                host: host, port: port, username: username, password: password, database: database,
                tls: tls)
        }
    }
}

extension PostgresClient.Configuration.TLS {
    public init(config: ConfigReader) {
        switch config.string(forKey: "base", as: TLSOption.self, default: .disable) {
        case .disable:
            self = .disable
        case .prefer:
            var tlsConfig = NIOSSL.TLSConfiguration.makeClientConfiguration()
            tlsConfig.configure(config)
            self = .prefer(tlsConfig)
        case .require:
            var tlsConfig = NIOSSL.TLSConfiguration.makeClientConfiguration()
            tlsConfig.configure(config)
            self = .require(tlsConfig)
        }
    }
}

extension NIOSSL.TLSConfiguration {
    public mutating func configure(_ config: ConfigReader) {
        if let minimumTLSVersion: NIOSSL.TLSVersion = config.string(forKey: "minimumTLSVersion") {
            self.minimumTLSVersion = minimumTLSVersion
        }

        if let maximumTLSVersion = config.string(
            forKey: "maximumTLSVersion", as: NIOSSL.TLSVersion.self)
        {
            self.maximumTLSVersion = maximumTLSVersion
        }

        if let cipherSuites = config.string(forKey: "cipherSuites") {
            self.cipherSuites = cipherSuites
        }

        // TODO: Important! This needs to be fleshed out to support SSL
    }
}

private enum TLSOption: String {
    case disable
    case prefer
    case require
}

extension TLSVersion: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "tlsv1": self = .tlsv1
        case "tlsv11": self = .tlsv11
        case "tlsv12": self = .tlsv12
        case "tlsv13": self = .tlsv13
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .tlsv1: return "tlsv1"
        case .tlsv11: return "tlsv11"
        case .tlsv12: return "tlsv12"
        case .tlsv13: return "tlsv13"
        }
    }
}
