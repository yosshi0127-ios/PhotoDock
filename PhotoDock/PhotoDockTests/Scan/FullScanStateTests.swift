//
//  FullScanStateTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 画面に戻るたびに診断が走り直す不具合を出したので、開始の条件をここで固定する。
@MainActor
@Suite("FullScanState")
struct FullScanStateTests {
    private let cardText = [RecognizedText(text: "4111 1111 1111 1111", confidence: 1, region: .test)]
    private let twoAssets: [AssetMetadata] = [.stub(id: "1"), .stub(id: "2")]

    private func makeState(
        pixels: SpyPixelSourceService,
        ocr: SpyOCRService = SpyOCRService(),
        records: SpyScanRecordRepository = SpyScanRecordRepository()
    ) -> FullScanState {
        withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = records
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            FullScanState()
        }
    }

    private func makePixels() -> SpyPixelSourceService {
        SpyPixelSourceService(outcome: .data(Data("image".utf8)))
    }

    /// .task は一覧から戻るたびに走る。2回目が素通りしないと診断が再開してしまう
    @Test("完了後に画面へ戻っても診断は再開しない")
    func startIfNeededRunsOnlyOnce() async {
        let pixels = makePixels()
        let state = makeState(pixels: pixels)

        await state.startIfNeeded(assets: twoAssets, quality: .quick)
        await state.startIfNeeded(assets: twoAssets, quality: .quick)

        #expect(await pixels.requestedIDs.count == 2)
    }

    @Test("もう一度診断では走り直す")
    func restartRunsAgain() async {
        let pixels = makePixels()
        let state = makeState(pixels: pixels)

        await state.startIfNeeded(assets: twoAssets, quality: .quick)
        await state.restart(assets: twoAssets, quality: .quick)

        #expect(await pixels.requestedIDs.count == 4)
    }

    @Test("所見のあった写真が一覧に溜まる")
    func collectsFlaggedPhotos() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: cardText))

        await state.startIfNeeded(assets: twoAssets, quality: .quick)

        #expect(Set(state.flagged.map(\.assetID)) == ["1", "2"])
        #expect(state.phase == .finished(ScanSummary(
            scanned: 2, notAvailableLocally: 0, missing: 0, dangerPhotos: 2, cautionPhotos: 0
        )))
    }

    /// 所見ゼロの写真まで溜めると、一覧が全件になってしまう
    @Test("所見がなければ一覧は空のまま")
    func noFlaggedWhenClean() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: []))

        await state.startIfNeeded(assets: twoAssets, quality: .quick)

        #expect(state.flagged.isEmpty)
    }

    @Test("再診断すると前回の一覧は残らない")
    func restartClearsFlagged() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: cardText))

        await state.startIfNeeded(assets: twoAssets, quality: .quick)
        await state.restart(assets: twoAssets, quality: .quick)

        #expect(state.flagged.count == 2)
    }

    /// 前回の記録だけで画面が成立する = アプリを開き直しても結果が残っている
    @Test("記録があれば診断せずに前回の結果が並ぶ")
    func restoresFromRecords() async {
        let pixels = makePixels()
        let record = ScanRecord(
            assetID: "1",
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .quick,
            generation: ProcessInfo.processInfo.operatingSystemVersionString,
            outcome: .scanned([StoredFinding(kind: .cardNumber, severity: .danger, region: .test)])
        )
        let state = makeState(pixels: pixels, records: SpyScanRecordRepository(records: [record]))

        await state.startIfNeeded(assets: [.stub(id: "1")], quality: .quick)

        #expect(state.flagged.map(\.assetID) == ["1"])
        #expect(await pixels.requestedIDs.isEmpty)
    }
}
