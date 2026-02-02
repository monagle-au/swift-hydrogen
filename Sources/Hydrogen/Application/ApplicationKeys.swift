//
//  ApplicationKeys.swift
//  swift-hydrogen
//
//  Created by David Monagle on 27/1/2026.
//

public struct ApplicationServiceKey: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    // ExpressibleByStringLiteral conformances
    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.rawValue = value
    }

    public init(unicodeScalarLiteral value: String) {
        self.rawValue = value
    }
}

public protocol ApplicationResourceKey {
    associatedtype Value
    static var name: String { get }
}

extension ApplicationResourceKey {
    public static var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: Self.self))
        hasher.combine(ObjectIdentifier(Self.self))
        return hasher.finalize()
    }
}
