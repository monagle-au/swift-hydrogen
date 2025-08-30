//
//  PostgresMigration.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 5/9/2024.
//

import PostgresNIO
@preconcurrency import UUIDKit

public protocol PostgresMigration {
    var name: String { get }
    var queries: [PostgresQuery] { get }
}

extension PostgresMigration {
    var uuid: UUID {
        UUID.v5(name: self.name, namespace: .migration)
    }
}

extension UUID.Namespace {
    public static let migration = UUID.Namespace(UUID(
        uuid: (0xef, 0xa3, 0xa5, 0xf6, 0xad, 0x2d, 0x40, 0xb3, 0x86, 0x6f, 0x24, 0xe5, 0xa9, 0x03, 0xd2, 0x87)
    ))
}
