//
//  Severity.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// 所見の重大度。
/// 「所見が無い」は `[Finding]` が空であることで表すので、safe や none のケースは持たない。
/// 宣言順が大小になる（caution < danger）。写真グリッドのバッジは `max()` で決める。
// String の raw value は保存形式のため（"danger" と残るほうが1年後に読める）。
// raw value を持つ enum には Comparable が合成されないので、順序は明示する
enum Severity: String, Sendable, Equatable, Hashable, Comparable, Codable {
    case caution
    case danger

    /// 段階の高さ。case を足したらここも書く（switch が網羅なのでコンパイルエラーで気づく）
    private var rank: Int {
        switch self {
        case .caution: 0
        case .danger: 1
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// 1件の所見（メモリ上のスキャン結果）。
/// 永続化するレコードは別型にして maskedText を持たせない（本文由来の情報を端末に残さない）。
/// この型を作れるのは Policy だけ。kind と severity の対応は Policy が唯一の決定者。
struct Finding: Sendable, Equatable, Hashable {
    let kind: FindingKind
    let severity: Severity
    let region: Region
    let maskedText: String
}

extension [Finding] {
    /// 写真1枚の重大度は、含まれる所見のうち最も高いもの。
    /// 所見がなければ nil（Severity に「安全」のケースを持たせない設計に合わせる）
    var highestSeverity: Severity? {
        map(\.severity).max()
    }
}
