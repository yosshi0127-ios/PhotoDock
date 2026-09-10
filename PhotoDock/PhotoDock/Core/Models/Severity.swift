//
//  Severity.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// 所見の重大度。
/// 「所見が無い」は `[Finding]` が空であることで表すので、safe や none のケースは持たない。
/// 宣言順が大小になる（caution < danger）。写真グリッドのバッジは `max()` で決める。
enum Severity: Sendable, Equatable, Hashable, Comparable {
    case caution
    case danger
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
