//
//  ScanPhotoUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 依存2本（pixelSource / ocr）を同時に差し替えて、段取りを検証する。
/// 判断の正しさは FindingPolicy のテストが持つので、ここでは「順序」と「渡し方」を見る。
@Suite("ScanPhotoUseCase")
struct ScanPhotoUseCaseTests {
    /// 画像は取れたことにするだけなので中身は問わない
    private let anyImageData = Data("image".utf8)

    private func scan(
        pixels: SpyPixelSourceService,
        ocr: SpyOCRService,
        quality: ScanQuality = .precise
    ) async -> PhotoScanOutcome {
        await withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanPhotoUseCase()
            return await useCase(assetID: "stub-0", quality: quality)
        }
    }

    /// iCloud 上の写真に OCR を走らせると、3万枚のうち多数を占めうる分だけ無駄な推論が走る
    @Test("iCloud にしか無い写真では OCR を呼ばない")
    func skipsOCRWhenNotAvailableLocally() async {
        let pixels = SpyPixelSourceService(outcome: .notAvailableLocally)
        let ocr = SpyOCRService()

        let outcome = await scan(pixels: pixels, ocr: ocr)

        #expect(outcome == .notAvailableLocally)
        #expect(await ocr.callCount == 0)
    }

    @Test("見つからない写真では OCR を呼ばない")
    func skipsOCRWhenMissing() async {
        let pixels = SpyPixelSourceService(outcome: .missing)
        let ocr = SpyOCRService()

        let outcome = await scan(pixels: pixels, ocr: ocr)

        #expect(outcome == .missing)
        #expect(await ocr.callCount == 0)
    }

    @Test("受け取った asset ID をそのまま pixelSource に渡す")
    func passesAssetIDThrough() async {
        let pixels = SpyPixelSourceService(outcome: .data(anyImageData))
        let ocr = SpyOCRService()

        _ = await scan(pixels: pixels, ocr: ocr)

        #expect(await pixels.requestedIDs == ["stub-0"])
    }

    /// ScanQuality を作った意味そのもの。無視する実装になっても
    /// 「遅いだけ／精度が低いだけ」で正常に見えるため、渡され方を固定する
    @Test("品質プリセットの maxPixelSize がそのまま OCR に渡る", arguments: ScanQuality.allCases)
    func passesMaxPixelSizeThrough(_ quality: ScanQuality) async {
        let pixels = SpyPixelSourceService(outcome: .data(anyImageData))
        let ocr = SpyOCRService()

        _ = await scan(pixels: pixels, ocr: ocr, quality: quality)

        #expect(await ocr.receivedMaxPixelSizes == [quality.maxPixelSize])
    }

    @Test("クイックと精密で渡す値が違う")
    func qualityPresetsDiffer() {
        #expect(ScanQuality.quick.maxPixelSize < ScanQuality.precise.maxPixelSize)
    }

    @Test("OCR の結果が Policy を通って所見になる")
    func classifiesRecognizedText() async {
        let pixels = SpyPixelSourceService(outcome: .data(anyImageData))
        let ocr = SpyOCRService(texts: [
            RecognizedText(text: "4111 1111 1111 1111", confidence: 1, region: .test),
            RecognizedText(text: "こんにちは", confidence: 1, region: .test)
        ])

        let outcome = await scan(pixels: pixels, ocr: ocr)

        // カード番号だけが所見になり、ただの文字列は落ちる
        #expect(outcome == .scanned([
            Finding(
                kind: .cardNumber,
                severity: .danger,
                region: .test,
                maskedText: "**** **** **** 1111"
            )
        ]))
    }

    /// 「診断して何も無かった」を「診断できなかった」と混ぜないための固定
    @Test("何も検出されなければ 0件の scanned が返る")
    func scannedWithNoFindings() async {
        let pixels = SpyPixelSourceService(outcome: .data(anyImageData))
        let ocr = SpyOCRService(texts: [
            RecognizedText(text: "ただの文字", confidence: 1, region: .test)
        ])

        let outcome = await scan(pixels: pixels, ocr: ocr)

        #expect(outcome == .scanned([]))
    }
}
