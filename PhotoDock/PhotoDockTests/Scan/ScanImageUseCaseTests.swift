//
//  ScanImageUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 画像データ1枚を診断する経路（写真詳細画面が使う入口）。
/// 判断の中身は FindingPolicy のテストが持つので、ここでは入口の契約と
/// 「ライブラリ経路と同じパイプラインを通ること」を固定する。
@Suite("ScanImageUseCase")
struct ScanImageUseCaseTests {
    /// OCR は Spy が差し替えるので中身は問わない
    private let anyImageData = Data("image".utf8)

    /// カード番号1行 + 何でもない1行。Policy が前者だけ拾う
    private let cardAndGreeting = [
        RecognizedText(text: "4111 1111 1111 1111", confidence: 1, region: .test),
        RecognizedText(text: "こんにちは", confidence: 1, region: .test)
    ]

    /// 診断できた場合の所見。失敗したらテストを落とす
    private func scan(
        ocr: SpyOCRService,
        faces: SpyFaceDetectionService = SpyFaceDetectionService(),
        quality: ScanQuality = .precise
    ) async -> [Finding] {
        guard case let .scanned(findings) = await outcome(ocr: ocr, faces: faces, quality: quality) else {
            Issue.record("診断できるはずの入力で failed が返った")
            return []
        }
        return findings
    }

    private func outcome(
        ocr: SpyOCRService,
        faces: SpyFaceDetectionService = SpyFaceDetectionService(),
        quality: ScanQuality = .precise
    ) async -> ImageScanOutcome {
        await withDependencies {
            $0.ocr = ocr
            $0.faceDetection = faces
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanImageUseCase()
            return await useCase(imageData: anyImageData, quality: quality)
        }
    }

    @Test("OCR の結果が Policy を通って所見になる")
    func classifiesRecognizedText() async {
        let findings = await scan(ocr: SpyOCRService(texts: cardAndGreeting))

        #expect(findings == [
            Finding(
                kind: .cardNumber,
                severity: .danger,
                region: .test,
                maskedText: "**** **** **** 1111"
            )
        ])
    }

    /// 「診断して何も無かった」写真が大半を占めるので、0件が正常系であることを固定する
    @Test("文字が読めなければ所見も0件")
    func noFindingsWhenNoText() async {
        let findings = await scan(ocr: SpyOCRService(texts: []))

        #expect(findings.isEmpty)
    }

    /// 「読めなかった」を「文字が無かった」に丸めると、見ていない写真が診断済みになる
    @Test("OCR が失敗したら、所見0件ではなく failed を返す")
    func failsWhenOCRFails() async {
        let result = await outcome(ocr: SpyOCRService(outcome: .failed))

        #expect(result == .failed)
    }

    /// 顔だけ見て「診断できた」にすると、文字を見ていない写真が記録に残る
    @Test("OCR が失敗したら、顔が見つかっていても failed")
    func failsEvenWhenFacesAreFound() async {
        let faces = SpyFaceDetectionService(faces: [
            DetectedFace(region: Region(x: 0.9, y: 0.05, width: 0.05, height: 0.06), yaw: nil)
        ])

        let result = await outcome(ocr: SpyOCRService(outcome: .failed), faces: faces)

        #expect(result == .failed)
    }

    /// 無視する実装になっても「遅いだけ／精度が低いだけ」で正常に見えるため、渡され方を固定する
    @Test("品質プリセットの maxPixelSize がそのまま OCR に渡る", arguments: ScanQuality.allCases)
    func passesMaxPixelSizeThrough(_ quality: ScanQuality) async {
        let ocr = SpyOCRService(texts: [])

        _ = await scan(ocr: ocr, quality: quality)

        #expect(await ocr.receivedMaxPixelSizes == [quality.maxPixelSize])
    }

    /// brief 124行「一括・詳細で同一 UseCase を通す」の固定。
    /// ScanPhotoUseCase が委譲をやめて自前で Policy を呼び始めたら落ちる。
    /// パイプラインが2つに分裂すると「一括では見逃すのに詳細では出る」が起きる。
    @Test("ライブラリ経路と画像データ経路で所見が一致する")
    func bothRoutesProduceSameFindings() async {
        let direct = await scan(ocr: SpyOCRService(texts: cardAndGreeting))

        let viaLibrary = await withDependencies {
            $0.pixelSource = SpyPixelSourceService(outcome: .data(anyImageData))
            $0.ocr = SpyOCRService(texts: cardAndGreeting)
            $0.faceDetection = SpyFaceDetectionService()
        } operation: {
            let useCase = ScanPhotoUseCase()
            return await useCase(assetID: "stub-0", quality: .precise, mode: .localOnly)
        }

        #expect(viaLibrary == .scanned(direct))
    }

    /// 顔検出も OCR と同じ縮小率で走らせる。ずれると詳細画面で顔枠と文字枠の座標系が合わない
    @Test("顔検出にも同じ maxPixelSize が渡り、写り込みらしい顔が所見になる")
    func facesFlowIntoFindings() async {
        let faces = SpyFaceDetectionService(faces: [
            DetectedFace(region: Region(x: 0.9, y: 0.05, width: 0.05, height: 0.06), yaw: nil)
        ])

        let findings = await scan(ocr: SpyOCRService(texts: []), faces: faces, quality: .quick)

        #expect(findings.map(\.kind) == [.bystanderFace])
        #expect(await faces.receivedMaxPixelSizes == [ScanQuality.quick.maxPixelSize])
    }
}
