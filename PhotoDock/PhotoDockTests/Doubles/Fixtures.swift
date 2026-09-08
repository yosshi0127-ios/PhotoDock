//
//  Fixtures.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

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

extension Region {
    /// 領域そのものを検証しないテストで使う置き場所
    static let test = Region(x: 0, y: 0, width: 1, height: 1)
}
