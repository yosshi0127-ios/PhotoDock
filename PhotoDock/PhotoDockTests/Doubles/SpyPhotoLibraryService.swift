//
//  SpyPhotoLibraryService.swift
//  PhotoDockTests
//

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
