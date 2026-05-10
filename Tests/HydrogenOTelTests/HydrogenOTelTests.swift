//
//  HydrogenOTelTests.swift
//  swift-hydrogen
//

import HydrogenOTel
import Testing

@Suite("HydrogenOTel namespace")
struct HydrogenOTelNamespaceTests {
    @Test("namespace is reachable")
    func namespaceReachable() {
        // Compile-time assertion: the type exists and is referenceable.
        _ = HydrogenOTel.self
    }
}
