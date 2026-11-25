//
//  Color+Theme.swift
//  PhotoDock
//

import SwiftUI
import UIKit

/// 画面で使う色。**View からは必ずここを通す**（`.red` や 16進の直書きをしない）。
///
/// 名前は見た目ではなく役割で付ける（`ground` / `ink` / `danger`）。
/// 値は `ThemePalette` にあり、外観モード（ライト／ダーク）に追従する
extension Color {
    /// 画面の地
    static let ground = Color(\.ground)
    /// カードや表の面
    static let surface = Color(\.surface)
    /// 表の見出し行・補足の囲みなど、面より一段沈めた面
    static let surfaceMuted = Color(\.surfaceMuted)
    /// 本文の文字
    static let ink = Color(\.ink)
    /// 補足の文字（日付・説明・単位）
    static let inkSecondary = Color(\.inkSecondary)
    /// 主役の色（主ボタン・リンク・「所見なし」）。SwiftUI の `accentColor` とは別物
    static let themeAccent = Color(\.accent)
    /// themeAccent で塗った上に置く文字
    static let onAccent = Color(\.onAccent)
    /// themeAccent の薄い面
    static let accentSurface = Color(\.accentSurface)
    /// 危険
    static let danger = Color(\.danger)
    /// danger で塗った上に置く文字
    static let onDanger = Color(\.onDanger)
    /// 危険の行の地
    static let dangerSurface = Color(\.dangerSurface)
    /// 要注意（結果票では「要確認」）
    static let caution = Color(\.caution)
    /// 要注意の行の地
    static let cautionSurface = Color(\.cautionSurface)
    /// 罫線・枠線
    static let hairline = Color(\.hairline)

    /// パレットの1項目を、外観モードに追従する色にする。
    ///
    /// UIKit の色を経由するのは**このファイルだけ**。アセットカタログの色にすれば SwiftUI だけで書けるが、
    /// 値がカタログの中に入り、コントラスト比をテストで確かめられなくなる（`ThemePaletteTests`）。
    /// `ShapeStyle` を自作する手もあるが、`Canvas` の塗りなど `Color` そのものを要求する箇所で使えない
    private init(_ token: KeyPath<ThemePalette, UInt32> & Sendable) {
        self.init(uiColor: UIColor { traits in
            let palette: ThemePalette = traits.userInterfaceStyle == .dark ? .dark : .light
            return UIColor(hex: palette[keyPath: token])
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
