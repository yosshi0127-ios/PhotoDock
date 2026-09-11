//
//  VisionOCRServiceTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 本物の Vision を通して「画像 → 文字 → 座標」の経路を固定する。
///
/// 入力は `StubPixelSourceService` が描く合成画像（600×400・x=40・y=60 と 140・フォント 40pt）。
/// 特に座標変換は、間違っていても画面を目で見るまで気づかないので、ここで数値として押さえる。
@Suite("VisionOCRService")
struct VisionOCRServiceTests {
    private let sut = VisionOCRService()
    private let pixels = StubPixelSourceService()

    /// カード番号が描かれた画像（stub-0）のバイト列
    private func cardImageData() async throws -> Data {
        guard case let .data(data) = await pixels.fetchImageData(for: "stub-0", mode: .localOnly) else {
            throw TestError.fixtureUnavailable
        }
        return data
    }

    @Test("描かれた文字を読み、行ごとに RecognizedText を返す")
    func recognizesRenderedLines() async throws {
        let results = await sut.recognizeText(in: try await cardImageData(), maxPixelSize: 2_000)

        #expect(results.count == 2)
        #expect(results.contains { $0.text.replacingOccurrences(of: " ", with: "").contains("4111111111111111") })
        #expect(results.contains { $0.text.contains("YAMADA") })
    }

    /// Vision は左下原点で返すので、変換を忘れると上下が反転する。
    /// 画像の上端（y=60/400 ≒ 0.15）に描いた行が、上半分に来ることを確認する。
    @Test("Region が左上原点になっている（上の行が小さい y を持つ）")
    func regionUsesTopLeftOrigin() async throws {
        let results = await sut.recognizeText(in: try await cardImageData(), maxPixelSize: 2_000)

        let card = try #require(results.first { $0.text.contains("4111") })
        let name = try #require(results.first { $0.text.contains("YAMADA") })

        // 変換を忘れると card.y は 0.7 付近になる
        #expect(card.y < 0.4)
        // 画像上で card は name の上に描かれている
        #expect(card.y < name.y)
        // x は 40/600 ≒ 0.067。左端寄りにあること
        #expect(card.region.x > 0)
        #expect(card.region.x < 0.2)
    }

    @Test("maxPixelSize まで縮小されるので、極端に小さくすると読めなくなる")
    func maxPixelSizeIsApplied() async throws {
        let data = try await cardImageData()

        let readable = await sut.recognizeText(in: data, maxPixelSize: 2_000)
        let tooSmall = await sut.recognizeText(in: data, maxPixelSize: 48)

        #expect(readable.contains { $0.text.contains("4111") })
        #expect(!tooSmall.contains { $0.text.contains("4111") })
    }

    @Test("画像として読めないデータは空配列（1枚の失敗でスキャンを止めない）")
    func brokenDataYieldsNoResults() async {
        let results = await sut.recognizeText(in: Data("not an image".utf8), maxPixelSize: 2_000)

        #expect(results.isEmpty)
    }

    // MARK: - 前段（文字らしい矩形の有無で OCR を省く）

    /// 前段が文字を落とすと、その写真は OCR に届かず所見ゼロになる。
    /// 「速いが見逃す」は製品として成り立たないので、文字入りが通ることを固定する
    @Test("文字のある画像は前段を通過して OCR に回る")
    func prefilterPassesImagesWithText() async throws {
        let image = try #require(VisionImageDecoder.decode(try await cardImageData(), maxPixelSize: 1_024))

        #expect(VisionOCRService.containsTextRectangles(in: image))
    }

    /// 大半の写真には文字が無い。ここを弾けるかどうかが 3 倍速の正体
    @Test("文字のない画像は前段で止まる")
    func prefilterStopsImagesWithoutText() async throws {
        // stub-1 は StubPixelSourceService が文字なしで描く白地の画像
        guard case let .data(data) = await pixels.fetchImageData(for: "stub-1", mode: .localOnly) else {
            throw TestError.fixtureUnavailable
        }
        let image = try #require(VisionImageDecoder.decode(data, maxPixelSize: 1_024))

        #expect(!VisionOCRService.containsTextRectangles(in: image))
    }

    private enum TestError: Error {
        case fixtureUnavailable
    }
}

private extension RecognizedText {
    /// 領域の上端。テストの意図（上下関係）を読みやすくするための別名
    var y: Double { region.y }
}
