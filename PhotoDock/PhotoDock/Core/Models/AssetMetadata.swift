//
//  AssetMetadata.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/01.
//

import Foundation

/// 写真のメタデータ
/// 画像データを読まずに取れる情報だけを持つ。
struct AssetMetadata: Sendable, Identifiable, Hashable {
    /// 一意な識別子
    let id: String
    /// 撮影日時
    let creationDate: Date?
    /// 最終更新日時
    let modificationDate: Date?
    /// 位置情報
    let coordinate: GeoCoordinate?
    /// スクショかどうか
    let isScreenshot: Bool
}
