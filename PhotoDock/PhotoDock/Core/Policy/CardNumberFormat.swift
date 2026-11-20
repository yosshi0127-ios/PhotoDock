//
//  CardNumberFormat.swift
//  PhotoDock
//

/// カードブランドの番号の形（先頭の番号帯と桁数）。
///
/// Luhn は10個に1個の数字列が偶然通る。先頭の番号帯と桁数がブランドの割り当てに
/// 合っているかを併せて見ることで、注文番号や JAN コードのような無関係な数字列を
/// 「カード番号が写っています」と断定しないようにする。
struct CardNumberFormat: Sendable, Equatable {
    /// 先頭の番号帯。範囲の両端は同じ桁数で書く（`51...55` は先頭2桁、`2221...2720` は先頭4桁を見る）
    let prefixes: [ClosedRange<Int>]
    /// このブランドが発行する桁数
    let lengths: Set<Int>

    /// 数字だけの文字列（半角）が、このブランドの番号帯と桁数に合うか。チェックサムは見ない
    func matches(_ digits: String) -> Bool {
        guard lengths.contains(digits.count) else { return false }

        return prefixes.contains { range in
            let prefixLength = String(range.upperBound).count
            guard let prefix = Int(digits.prefix(prefixLength)) else { return false }

            return range.contains(prefix)
        }
    }
}
