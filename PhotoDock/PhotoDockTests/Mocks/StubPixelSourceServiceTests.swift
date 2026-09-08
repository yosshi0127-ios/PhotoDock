//
//  StubPixelSourceServiceTests.swift
//  PhotoDockTests
//

import Testing
import UIKit
import Vision
@testable import PhotoDock

/// Preview 用の合成画像が「目的を果たしているか」を確認する。
///
/// この Stub の価値は「決定的であること」と「機微情報が写った画像として通用すること」の2点なので、
/// 本物の Vision に通して実際に読めるところまで見る（1〜2枚なら数秒で終わる）。
@Suite("StubPixelSourceService")
struct StubPixelSourceServiceTests {
    private let sut = StubPixelSourceService()

    @Test("同じ id は必ず同じバイト列を返す（Preview の表示が毎回変わらないため）")
    func isDeterministic() async {
        let first = await sut.fetchImageData(for: "stub-0")
        let second = await sut.fetchImageData(for: "stub-0")

        #expect(first == second)
    }

    @Test("50枚に1枚は iCloud にあって取れない")
    func notAvailableLocally() async {
        #expect(await sut.fetchImageData(for: "stub-3") == .notAvailableLocally)
        #expect(await sut.fetchImageData(for: "stub-53") == .notAvailableLocally)
    }

    @Test("20枚に1枚はカード番号が写っていて、本物の OCR で読める")
    func cardNumberIsRecognizable() async throws {
        let text = try await recognizedText(for: "stub-0")

        // OCR は空白を保持して返すので、判定は正規化してから行う（brief の検証済みの事実）
        #expect(text.replacingOccurrences(of: " ", with: "").contains("4111111111111111"))
    }

    @Test("7枚に1枚は電話番号とメールが写っていて、本物の OCR で読める")
    func phoneAndMailAreRecognizable() async throws {
        let text = try await recognizedText(for: "stub-7")

        #expect(text.contains("090-1234-5678"))
        #expect(text.contains("@example.com"))
    }

    @Test("大半の写真には文字が写っていない")
    func mostPhotosHaveNoText() async throws {
        #expect(try await recognizedText(for: "stub-1").isEmpty)
        #expect(try await recognizedText(for: "stub-2").isEmpty)
    }

    /// Stub が返した画像を本物の Vision に通し、読めた行を1つの文字列に連結して返す
    private func recognizedText(for id: String) async throws -> String {
        guard case let .data(data) = await sut.fetchImageData(for: id),
              let cgImage = UIImage(data: data)?.cgImage else {
            return ""
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]

        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
