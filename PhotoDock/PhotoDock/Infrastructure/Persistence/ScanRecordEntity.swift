//
//  ScanRecordEntity.swift
//  PhotoDock
//

import Foundation
import SwiftData

/// SwiftData の保存形。ScanRecord との変換はこのファイルに閉じる（Core は SwiftData を知らない）。
@Model
final class ScanRecordEntity {
    @Attribute(.unique) var assetID: String
    var modificationDate: Date?
    var scannedAt: Date
    /// ScanQuality.rawValue
    var quality: String
    var generation: String
    /// ScanRecord.Outcome を JSON にしたもの。payload 付き enum は SwiftData の属性にすると
    /// 保存形式が不透明になるので、自前で符号化して中身を追えるようにしておく
    var outcome: Data

    init(
        assetID: String,
        modificationDate: Date?,
        scannedAt: Date,
        quality: String,
        generation: String,
        outcome: Data
    ) {
        self.assetID = assetID
        self.modificationDate = modificationDate
        self.scannedAt = scannedAt
        self.quality = quality
        self.generation = generation
        self.outcome = outcome
    }
}

extension ScanRecordEntity {
    convenience init(_ record: ScanRecord) throws {
        self.init(
            assetID: record.assetID,
            modificationDate: record.modificationDate,
            scannedAt: record.scannedAt,
            quality: record.quality.rawValue,
            generation: record.generation,
            outcome: try JSONEncoder().encode(record.outcome)
        )
    }

    /// 同じ assetID の行を上書きする
    func update(from record: ScanRecord) throws {
        modificationDate = record.modificationDate
        scannedAt = record.scannedAt
        quality = record.quality.rawValue
        generation = record.generation
        outcome = try JSONEncoder().encode(record.outcome)
    }

    /// 復元できない行（将来の schema 変更・壊れた JSON）は nil。
    /// 呼ぶ側は「記録なし」として扱い、その写真は再スキャンに回る（キャッシュなので失っても壊れない）
    func toRecord() -> ScanRecord? {
        guard let quality = ScanQuality(rawValue: quality),
              let outcome = try? JSONDecoder().decode(ScanRecord.Outcome.self, from: outcome) else {
            return nil
        }

        return ScanRecord(
            assetID: assetID,
            modificationDate: modificationDate,
            scannedAt: scannedAt,
            quality: quality,
            generation: generation,
            outcome: outcome
        )
    }
}
