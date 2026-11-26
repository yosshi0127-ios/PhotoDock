//
//  PhotoDispositionEntity.swift
//  PhotoDock
//

import Foundation
import SwiftData

/// SwiftData の保存形。PhotoDisposition との変換はこのファイルに閉じる（Core は SwiftData を知らない）。
@Model
final class PhotoDispositionEntity {
    @Attribute(.unique) var assetID: String
    /// PhotoDisposition.Action.rawValue
    var action: String
    var decidedAt: Date
    var modificationDate: Date?
    /// FindingKind.rawValue の並び。配列をそのまま属性にすると保存形式が不透明になるので、文字列で持つ
    var kinds: [String]

    init(assetID: String, action: String, decidedAt: Date, modificationDate: Date?, kinds: [String]) {
        self.assetID = assetID
        self.action = action
        self.decidedAt = decidedAt
        self.modificationDate = modificationDate
        self.kinds = kinds
    }
}

extension PhotoDispositionEntity {
    convenience init(_ disposition: PhotoDisposition) {
        self.init(
            assetID: disposition.assetID,
            action: disposition.action.rawValue,
            decidedAt: disposition.decidedAt,
            modificationDate: disposition.modificationDate,
            kinds: disposition.kinds.map(\.rawValue)
        )
    }

    /// 同じ assetID の行を上書きする
    func update(from disposition: PhotoDisposition) {
        action = disposition.action.rawValue
        decidedAt = disposition.decidedAt
        modificationDate = disposition.modificationDate
        kinds = disposition.kinds.map(\.rawValue)
    }

    /// 復元できない行（知らない対応の名前）は nil。知らない種類は、その種類だけを落とす
    /// （将来の版で種類が増えたあと、古い版に戻しても対応そのものは残す）
    func toDisposition() -> PhotoDisposition? {
        guard let action = PhotoDisposition.Action(rawValue: action) else { return nil }
        return PhotoDisposition(
            assetID: assetID,
            action: action,
            decidedAt: decidedAt,
            modificationDate: modificationDate,
            kinds: kinds.compactMap(FindingKind.init(rawValue:))
        )
    }
}
