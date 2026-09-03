//
//  TestDoubles.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出し回数を記録する `PhotoLibraryService`。
///
/// 可変状態を持つのに protocol は Sendable を要求するので actor にする。
/// class + @unchecked Sendable + ロックでも書けるが、隔離をコンパイラに任せられるこちらを選ぶ。
actor SpyPhotoLibraryService: PhotoLibraryService {
    private let stubbedAccess: PhotoLibraryAccess
    private let stubbedAssets: [AssetMetadata]

    private(set) var currentAccessCallCount = 0
    private(set) var requestAccessCallCount = 0
    private(set) var fetchCallCount = 0

    init(access: PhotoLibraryAccess, assets: [AssetMetadata] = []) {
        self.stubbedAccess = access
        self.stubbedAssets = assets
    }

    func currentAccess() async -> PhotoLibraryAccess {
        currentAccessCallCount += 1
        return stubbedAccess
    }

    func requestAccess() async -> PhotoLibraryAccess {
        requestAccessCallCount += 1
        return stubbedAccess
    }

    func fetchAllAssetMetadata() async -> [AssetMetadata] {
        fetchCallCount += 1
        return stubbedAssets
    }
}

extension AssetMetadata {
    /// テスト用の組み立てヘルパー。関心のあるフィールドだけ指定する。
    static func stub(
        id: String = "asset",
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        coordinate: GeoCoordinate? = nil,
        isScreenshot: Bool = false
    ) -> AssetMetadata {
        AssetMetadata(
            id: id,
            creationDate: creationDate,
            modificationDate: modificationDate,
            coordinate: coordinate,
            isScreenshot: isScreenshot
        )
    }
}

extension GeoCoordinate {
    static let anywhere = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)
}
