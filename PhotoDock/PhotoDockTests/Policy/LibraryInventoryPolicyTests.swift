//
//  LibraryInventoryPolicyTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

@Suite("LibraryInventoryPolicy")
struct LibraryInventoryPolicyTests {
    private let policy = LibraryInventoryPolicy()

    @Test("空のライブラリはすべて0")
    func emptyLibrary() {
        #expect(policy.inventory(of: []) == LibraryInventory(total: 0, withLocation: 0, screenshots: 0))
    }

    @Test("位置情報付きとスクリーンショットをそれぞれ数える")
    func counts() {
        let assets: [AssetMetadata] = [
            .stub(id: "1", coordinate: .anywhere),
            .stub(id: "2"),
            .stub(id: "3", isScreenshot: true),
            .stub(id: "4"),
            .stub(id: "5", isScreenshot: true)
        ]

        #expect(policy.inventory(of: assets) == LibraryInventory(total: 5, withLocation: 1, screenshots: 2))
    }

    @Test("位置情報付きのスクリーンショットは両方に数える")
    func overlap() {
        let assets: [AssetMetadata] = [
            .stub(id: "1", coordinate: .anywhere, isScreenshot: true)
        ]

        // 2つの数え上げは互いに独立。合計と一致する必要はない
        #expect(policy.inventory(of: assets) == LibraryInventory(total: 1, withLocation: 1, screenshots: 1))
    }

    @Test("位置情報を持たない写真だけなら withLocation は0")
    func noLocation() {
        let assets = (0..<10).map { AssetMetadata.stub(id: "\($0)") }

        #expect(policy.inventory(of: assets) == LibraryInventory(total: 10, withLocation: 0, screenshots: 0))
    }
}
