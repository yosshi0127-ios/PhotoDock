//
//  ThemePalette.swift
//  PhotoDock
//

import Foundation

/// 配色の原本。値は 0xRRGGBB。
///
/// 画面からは直接使わず、`Color` の拡張（`Color+Theme.swift`）を通す。
/// ここを値の表にしているのは、文字と地のコントラスト比をテストで確かめるため
/// （`ThemePaletteTests`。色を変えて読めなくなる事故を機械で止める）。
///
/// 雰囲気は「検診の結果票」: 落ち着いた緑みの地に、判定の色（危険・要注意）だけを強く出す
struct ThemePalette: Sendable, Equatable {
    /// 画面の地
    let ground: UInt32
    /// カードや表の面
    let surface: UInt32
    /// 表の見出し行・補足の囲みなど、面より一段沈めた面
    let surfaceMuted: UInt32
    /// 本文の文字
    let ink: UInt32
    /// 補足の文字（日付・説明・単位）
    let inkSecondary: UInt32
    /// 主役の色（主ボタン・リンク・「所見なし」）
    let accent: UInt32
    /// accent で塗った上に置く文字
    let onAccent: UInt32
    /// accent の薄い面（チェックの丸など）
    let accentSurface: UInt32
    /// 危険
    let danger: UInt32
    /// danger で塗った上に置く文字
    let onDanger: UInt32
    /// 危険の行の地
    let dangerSurface: UInt32
    /// 要注意（結果票では「要確認」）
    let caution: UInt32
    /// 要注意の行の地
    let cautionSurface: UInt32
    /// 罫線・枠線
    let hairline: UInt32

    static let light = ThemePalette(
        ground: 0xF4F7F5,
        surface: 0xFFFFFF,
        surfaceMuted: 0xEAF0ED,
        ink: 0x16211D,
        inkSecondary: 0x4A5A54,
        accent: 0x0F6B5C,
        onAccent: 0xFFFFFF,
        accentSurface: 0xDDEDE8,
        danger: 0xA8301F,
        onDanger: 0xFFFFFF,
        dangerSurface: 0xFCEFED,
        caution: 0x8A4B00,
        cautionSurface: 0xFDF7EB,
        hairline: 0xD5DED9
    )

    static let dark = ThemePalette(
        ground: 0x0F1513,
        surface: 0x19211E,
        surfaceMuted: 0x222C28,
        ink: 0xE9EFEC,
        inkSecondary: 0xA7B5AF,
        accent: 0x5CC4AE,
        onAccent: 0x06231D,
        accentSurface: 0x143029,
        danger: 0xFF8F80,
        onDanger: 0x2A0B07,
        dangerSurface: 0x3A1814,
        caution: 0xF0B762,
        cautionSurface: 0x33250C,
        hairline: 0x2E3A35
    )

    /// 文字として読ませる組み合わせ（文字, 地）。どれも WCAG のコントラスト比 4.5 以上を保つ
    var textPairs: [(text: UInt32, background: UInt32)] {
        [
            (ink, ground), (ink, surface), (ink, surfaceMuted), (ink, dangerSurface), (ink, cautionSurface),
            (inkSecondary, ground), (inkSecondary, surface), (inkSecondary, surfaceMuted),
            (accent, ground), (accent, surface), (accent, accentSurface), (onAccent, accent),
            (danger, surface), (danger, dangerSurface), (onDanger, danger),
            (caution, surface), (caution, cautionSurface)
        ]
    }

    /// WCAG 2 のコントラスト比（1...21）
    static func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        let lighter = max(relativeLuminance(first), relativeLuminance(second))
        let darker = min(relativeLuminance(first), relativeLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func linear(_ channel: UInt32) -> Double {
            let value = Double(channel) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((hex >> 16) & 0xFF) + 0.7152 * linear((hex >> 8) & 0xFF) + 0.0722 * linear(hex & 0xFF)
    }
}
