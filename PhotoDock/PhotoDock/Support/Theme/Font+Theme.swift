//
//  Font+Theme.swift
//  PhotoDock
//

import SwiftUI

/// 画面で使う文字の大きさ。**View からは必ずここを通す**（`.system(size:)` の直書きをしない）。
///
/// すべてテキストスタイルに乗せてあり、端末の文字サイズの設定（Dynamic Type）に追従する。
/// 書体は iOS の標準（フォントを同梱しない）
extension Font {
    /// 画面の題（「診断結果票」）
    static let screenTitle = Font.system(.title, weight: .bold)
    /// 総合判定の文言（「要確認 9 枚」）
    static let verdict = Font.system(.title2, weight: .bold)
    /// 総合判定の記号（A / B / C）
    static let verdictGrade = Font.system(.title, design: .rounded, weight: .bold)
    /// カードや節の見出し
    static let sectionTitle = Font.system(.headline)
    /// 表の行・本文
    static let rowLabel = Font.system(.body)
    /// 表の数値・判定（行の中で強調する側）
    static let rowValue = Font.system(.body, weight: .bold)
    /// 補足（日付・説明）
    static let note = Font.system(.footnote)
    /// 表の見出し行・札
    static let label = Font.system(.caption, weight: .medium)
    /// 主ボタンの文字
    static let action = Font.system(.body, weight: .bold)
}
