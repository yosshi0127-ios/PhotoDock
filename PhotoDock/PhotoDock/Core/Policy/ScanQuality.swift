//
//  ScanQuality.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

// String の raw value は保存形式のため（スキャン済み記録に "quick" と残る）。
// raw value を持つ enum には Comparable が合成されないので、順序は明示する
enum ScanQuality: String, Sendable, CaseIterable, Comparable, Codable {
    case quick
    case precise

    /// 長辺の最大ピクセル数。値は暫定（Phase 0 の実測で確定）
    var maxPixelSize: Int {
        switch self {
        case .quick: 1_024
        case .precise: 3_000
        }
    }

    /// 品質の高低 = 解像度の高低。「要求品質 > 記録品質なら再スキャン」をそのまま書けるようにする
    static func < (lhs: ScanQuality, rhs: ScanQuality) -> Bool {
        lhs.maxPixelSize < rhs.maxPixelSize
    }
}
