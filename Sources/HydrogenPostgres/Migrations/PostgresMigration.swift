//
//  PostgresMigration.swift
//  budget-forward-cloud
//
//  Created by David Monagle on 5/9/2024.
//

import PostgresNIO
@_exported @preconcurrency import UUIDKit

public protocol PostgresMigration {
    var name: String { get }
    var queries: [PostgresQuery] { get }
}
