//
//  ThemePaletteTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 配色を変えたときに、文字が読めなくなる組み合わせができていないかを確かめる。
/// 基準は WCAG の通常の文字（コントラスト比 4.5 以上）
@Suite("ThemePalette")
struct ThemePaletteTests {
    @Test("コントラスト比の計算が既知の値と合う")
    func contrastRatioMatchesKnownValues() {
        // 白と黒は 21、同じ色どうしは 1
        #expect(abs(ThemePalette.contrastRatio(0xFFFFFF, 0x000000) - 21) < 0.01)
        #expect(abs(ThemePalette.contrastRatio(0x777777, 0x777777) - 1) < 0.01)
        // 順序によらない
        #expect(ThemePalette.contrastRatio(0x0F6B5C, 0xFFFFFF) == ThemePalette.contrastRatio(0xFFFFFF, 0x0F6B5C))
    }

    @Test("文字として読ませる組み合わせは、すべてコントラスト比 4.5 以上", arguments: [
        ("ライト", ThemePalette.light),
        ("ダーク", ThemePalette.dark)
    ])
    func textPairsAreReadable(_ name: String, _ palette: ThemePalette) {
        let failures = palette.textPairs
            .map { (pair: $0, ratio: ThemePalette.contrastRatio($0.text, $0.background)) }
            .filter { $0.ratio < 4.5 }
            .map { String(format: "%06X on %06X = %.2f", $0.pair.text, $0.pair.background, $0.ratio) }

        #expect(failures.isEmpty, "\(name) で読みにくい組み合わせ: \(failures)")
    }

    /// ライトとダークで同じ色を使い回していると、片方で必ず読めなくなる
    @Test("ライトとダークで、地と文字が入れ替わっている")
    func lightAndDarkAreDistinct() {
        #expect(ThemePalette.light.ground != ThemePalette.dark.ground)
        #expect(ThemePalette.light.ink != ThemePalette.dark.ink)
    }
}
