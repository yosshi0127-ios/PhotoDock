//
//  ScanRecord.swift
//  PhotoDock
//

import Foundation

/// スキャン済み記録。「この写真をこの条件で診断した」という事実。
/// 所見ゼロの写真も記録する — 記録しないと「未スキャン」と区別できず、2回目以降が速くならない。
/// インデックスはただのキャッシュで、真実は常に最新のスキャン（再診断で差分が出たら上書き）。
struct ScanRecord: Sendable, Equatable, Codable {

    enum Outcome: Sendable, Equatable, Codable {
        case scanned([StoredFinding])
        /// 端末に無く、ダウンロードは許可されていなかった
        case notAvailableLocally
        /// ダウンロードを試したが iCloud 側にも実体が無かった
        case unavailableInCloud
        case missing
    }

    let assetID: String
    /// 写真がこの後に編集されていたら記録は無効（再スキャン）
    let modificationDate: Date?
    let scannedAt: Date
    /// 適用済みの品質。要求がこれより高ければ再スキャン
    let quality: ScanQuality
    /// スキャン時の OS バージョン（= Vision の世代）。変わっていたら再スキャン
    let generation: String
    let outcome: Outcome

    var findings: [StoredFinding] {
        if case let .scanned(findings) = outcome { findings } else { [] }
    }

    var isFlagged: Bool {
        findings.isEmpty == false
    }
}

extension ScanRecord {
    /// 診断結果を保存用に変換する。maskedText はここで落ちる
    init(_ photo: ScannedPhoto, asset: AssetMetadata, quality: ScanQuality, generation: String, scannedAt: Date) {
        self.assetID = asset.id
        self.modificationDate = asset.modificationDate
        self.scannedAt = scannedAt
        self.quality = quality
        self.generation = generation
        self.outcome = switch photo.outcome {
        case let .scanned(findings): .scanned(findings.map(StoredFinding.init))
        case .notAvailableLocally: .notAvailableLocally
        case .unavailableInCloud: .unavailableInCloud
        case .missing: .missing
        }
    }
}
