//
//  StubPixelSourceService.swift
//  PhotoDock
//

import UIKit

/// Preview 用の偽のピクセル取得。PhotoKit には触らず、文字を描いた画像を合成して返す。
/// 返す内容は id から決定的に決まる（Preview の表示が毎回変わらないようにするため）。
struct StubPixelSourceService: PixelSourceService {
    /// id の連番から、機微情報が写っている画像／何も写っていない画像／iCloud 上にある状態を出し分ける。
    func fetchImageData(for id: String, mode: PixelFetchMode) async -> PixelSourceOutcome {
        let index = Self.index(of: id)

        // 50枚に1枚は「iCloud にあって診断できない」状態。その表示も Preview で確認できるように
        guard index % 50 != 3 else { return .notAvailableLocally }
        guard let data = Self.render(lines: Self.lines(for: index)).pngData() else { return .missing }

        return .data(data)
    }

    /// Preview では縮小せず、診断と同じ合成画像をそのまま返す
    /// （一覧の見た目を確認するのが目的で、サイズは問題にならない）
    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data? {
        guard case let .data(data) = await fetchImageData(for: id, mode: .localOnly) else { return nil }
        return data
    }

    /// "stub-42" → 42。想定外の id は 0 扱い
    private static func index(of id: String) -> Int {
        Int(id.split(separator: "-").last ?? "") ?? 0
    }

    /// 20枚に1枚はカード番号（危険）、7枚に1枚は電話番号とメール（要注意）、残りは文字なし
    private static func lines(for index: Int) -> [String] {
        if index.isMultiple(of: 20) {
            ["4111 1111 1111 1111", "YAMADA TARO  12/28"]
        } else if index.isMultiple(of: 7) {
            ["090-1234-5678", "yamada@example.com"]
        } else {
            []
        }
    }

    /// 白地に黒文字で描く。色は固定値（`UIColor.label` のような動的色は
    /// 描画時のトレイトに依存して結果が変わるので、決定性のために使わない）。
    private static func render(lines: [String]) -> UIImage {
        let size = CGSize(width: 600, height: 400)

        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40),
                .foregroundColor: UIColor.black
            ]

            for (offset, line) in lines.enumerated() {
                let origin = CGPoint(x: 40, y: 60 + CGFloat(offset) * 80)
                (line as NSString).draw(at: origin, withAttributes: attributes)
            }
        }
    }
}
