//
//  StubOCRService.swift
//  PhotoDock
//

import Foundation

/// Preview 用の偽の OCR。Vision を呼ばず固定の結果を即座に返す。
///
/// 本物を previewValue にすると、Stub のライブラリ 1,240 枚に対して実際の推論が走り、
/// Preview が数分固まる。正しさはテストで担保し、Preview は速さを取る。
/// 画像の中身は見ないので、**Preview ではすべての写真に同じ所見が出る**（枚数の見た目は不自然になる）。
struct StubOCRService: OCRService {
    func recognizeText(in data: Data, maxPixelSize: Int) async -> [RecognizedText] {
        Self.fixedResults
    }

    /// 位置は `StubPixelSourceService` が文字を描く座標に合わせてある
    /// （600×400 の画像・x=40・y=60 と 140・フォント 40pt を正規化した値）。
    /// これで写真詳細のオーバーレイ Preview で、枠が実際の文字の上に乗る。
    private static let fixedResults = [
        RecognizedText(
            text: "4111 1111 1111 1111",
            confidence: 1,
            region: Region(x: 0.067, y: 0.150, width: 0.700, height: 0.120)
        ),
        RecognizedText(
            text: "YAMADA TARO  12/28",
            confidence: 0.98,
            region: Region(x: 0.067, y: 0.350, width: 0.640, height: 0.120)
        )
    ]
}
