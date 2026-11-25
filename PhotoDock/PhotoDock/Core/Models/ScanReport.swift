//
//  ScanReport.swift
//  PhotoDock
//

import Foundation

/// 診断結果票。スキャン済み記録を「検診の結果票」の形にまとめたもの。
///
/// 数え方は2通りあり、混ぜない:
/// - **総合判定と `dangerPhotos` / `cautionPhotos` は写真の枚数**（1枚は1回だけ数える）
/// - **`items` は項目（種類）ごとの枚数**。1枚に住所と電話番号が写っていれば両方の項目に出るので、
///   項目の合計は写真の枚数より多くなる
struct ScanReport: Sendable, Equatable {
    /// 総合判定。検診の結果票に合わせて3段階
    /// （根拠が「危険」と「要注意」の2種類しかないので、それ以上に刻まない）
    enum Grade: String, Sendable, Equatable, Comparable, CaseIterable {
        /// 所見なし
        case a = "A"
        /// 要確認の写真がある
        case b = "B"
        /// 危険の写真がある
        case c = "C"

        private var rank: Int {
            switch self {
            case .a: 0
            case .b: 1
            case .c: 2
            }
        }

        static func < (lhs: Grade, rhs: Grade) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    /// 項目ごとの判定
    enum Verdict: Sendable, Equatable {
        /// 所見なし
        case clear
        /// 要確認（severity の「要注意」。結果票の上では検診の言葉に合わせる）
        case caution
        /// 危険
        case danger
        /// 参考。枚数は出すが総合判定には数えない（顔の写り込み）
        case reference
    }

    /// 表の1行
    struct Item: Sendable, Equatable, Identifiable {
        let kind: FindingKind
        var verdict: Verdict
        /// この種類の所見がある写真の枚数
        var photoCount: Int

        var id: FindingKind { kind }
    }

    /// 診断できた枚数（所見ゼロを含む）
    var diagnosed: Int
    /// 危険の所見がある写真の枚数（参考の項目は数えない）
    var dangerPhotos: Int
    /// 要確認どまりの写真の枚数。危険と混在する写真は危険にだけ数える（参考の項目は数えない）
    var cautionPhotos: Int
    /// 項目ごとの行。順序と行数は固定（`ScanReportPolicy.itemOrder`）
    var items: [Item]
    /// 端末に無く、ダウンロードは許可されていなかった枚数
    var notAvailableLocally: Int
    /// ダウンロードを試したが iCloud 側にも実体が無かった枚数
    var unavailableInCloud: Int
    /// 文字を読む処理が失敗した枚数
    var failed: Int
    /// 写真が見つからなかった枚数
    var missing: Int
    /// 最後に診断した日時。記録が1件も無ければ nil
    var lastScannedAt: Date?

    /// 総合判定
    var grade: Grade {
        if dangerPhotos > 0 { return .c }
        if cautionPhotos > 0 { return .b }
        return .a
    }

    /// 確認が必要な写真の枚数（危険 + 要確認）
    var attentionPhotos: Int { dangerPhotos + cautionPhotos }

    /// 診断できていない枚数。結果票の「所見なし」に含めてはいけない
    var undiagnosed: Int { notAvailableLocally + unavailableInCloud + failed + missing }

    /// 記録に載っている写真の合計
    var total: Int { diagnosed + undiagnosed }
}
