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
    private let threeAssets: [AssetMetadata] = [.stub(id: "1"), .stub(id: "2"), .stub(id: "3")]

    private func makeState(
        pixels: SpyPixelSourceService,
        ocr: SpyOCRService = SpyOCRService(),
        records: SpyScanRecordRepository = SpyScanRecordRepository(),
        continuation: SpyContinuedProcessingService = SpyContinuedProcessingService()
    ) -> FullScanState {
        withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = records
            $0.network = SpyNetworkStatusService(unmetered: false)
            $0.continuedProcessing = continuation
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            FullScanState()
        }
    }

    private func makePixels() -> SpyPixelSourceService {
        SpyPixelSourceService(outcome: .data(Data("image".utf8)))
    }

    /// 開始は同期で返る（View が待つと State を掴み続けて閉じられなくなる）ので、テストでは終わりを待つ
    private func start(_ state: FullScanState, assets: [AssetMetadata]) async {
        state.startIfNeeded(assets: assets, quality: .quick)
        await state.waitUntilSettled()
    }

    private func restart(_ state: FullScanState, assets: [AssetMetadata]) async {
        state.restart(assets: assets, quality: .quick)
        await state.waitUntilSettled()
    }

    /// onAppear は一覧から戻るたびに走る。2回目が素通りしないと診断が再開してしまう
    @Test("完了後に画面へ戻っても診断は再開しない")
    func startIfNeededRunsOnlyOnce() async {
        let pixels = makePixels()
        let state = makeState(pixels: pixels)

        await start(state, assets: twoAssets)
        await start(state, assets: twoAssets)

        #expect(await pixels.requestedIDs.count == 2)
    }

    @Test("もう一度診断では走り直す")
    func restartRunsAgain() async {
        let pixels = makePixels()
        let state = makeState(pixels: pixels)

        await start(state, assets: twoAssets)
        await restart(state, assets: twoAssets)

        #expect(await pixels.requestedIDs.count == 4)
    }

    @Test("所見のあった写真が一覧に溜まる")
    func collectsFlaggedPhotos() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: cardText))

        await start(state, assets: twoAssets)

        #expect(Set(state.flagged.map(\.assetID)) == ["1", "2"])
        guard case let .finished(report) = state.phase else {
            Issue.record("finished になっていない: \(state.phase)")
            return
        }
        #expect(report.diagnosed == 2)
        #expect(report.dangerPhotos == 2)
    }

    /// 診断中の画面は、流れてきた記録で結果票の表を埋める
    @Test("結果票の項目が、見つかった種類で埋まる")
    func fillsReportItems() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: cardText))

        await start(state, assets: twoAssets)

        let card = state.report.items.first { $0.kind == .cardNumber }
        #expect(card?.verdict == .danger)
        #expect(card?.photoCount == 2)
        #expect(state.report.grade == .c)
    }

    @Test("始める前の結果票は、全項目が空")
    func reportIsEmptyBeforeStart() {
        let state = makeState(pixels: makePixels())

        #expect(state.report == ScanReportPolicy().empty)
    }

    /// 所見ゼロの写真まで溜めると、一覧が全件になってしまう
    @Test("所見がなければ一覧は空のまま")
    func noFlaggedWhenClean() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: []))

        await start(state, assets: twoAssets)

        #expect(state.flagged.isEmpty)
    }

    @Test("再診断すると前回の一覧は残らない")
    func restartClearsFlagged() async {
        let state = makeState(pixels: makePixels(), ocr: SpyOCRService(texts: cardText))

        await start(state, assets: twoAssets)
        await restart(state, assets: twoAssets)

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
            generation: ScanRecordPolicy().generation(osVersion: ProcessInfo.processInfo.operatingSystemVersionString),
            outcome: .scanned([StoredFinding(kind: .cardNumber, severity: .danger, region: .test)])
        )
        let state = makeState(pixels: pixels, records: SpyScanRecordRepository(records: [record]))

        await start(state, assets: [.stub(id: "1")])

        #expect(state.flagged.map(\.assetID) == ["1"])
        #expect(await pixels.requestedIDs.isEmpty)
    }

    // MARK: - 中断

    /// OS に打ち切られた（Live Activity から中止された）ら、途中の数字を完了として見せない
    @Test("全件流れ切る前に止まったら interrupted になる")
    func interruptedWhenStoppedEarly() async {
        let state = makeState(
            pixels: makePixels(),
            continuation: SpyContinuedProcessingService(expiresAfterReports: 1)
        )

        await start(state, assets: threeAssets)

        // 1枚目の報告で打ち切られるので、流れるのは1枚だけ
        guard case let .interrupted(report) = state.phase else {
            Issue.record("interrupted になっていない: \(state.phase)")
            return
        }
        #expect(report.diagnosed == 1)
        #expect(state.total == 3)
        #expect(state.remainingSeconds == nil)
    }

    /// 画面の「中断する」。終わるのを待たずに止まり、途中の数字を完了として見せない
    @Test("中断すると、全件が流れる前に interrupted になる")
    func stopInterruptsScan() async {
        let state = makeState(pixels: makePixels())
        let moreThanCanFinish = (0..<6_000).map { AssetMetadata.stub(id: "\($0)") }

        state.startIfNeeded(assets: moreThanCanFinish, quality: .quick)
        state.stop()
        await state.waitUntilSettled()

        guard case let .interrupted(report) = state.phase else {
            Issue.record("interrupted になっていない: \(state.phase)")
            return
        }
        #expect(report.total < 6_000)
    }

    @Test("診断していないときの中断は何もしない")
    func stopDoesNothingWhenNotScanning() async {
        let state = makeState(pixels: makePixels())

        state.stop()
        #expect(state.phase == .idle)

        await start(state, assets: twoAssets)
        let finished = state.phase
        state.stop()
        #expect(state.phase == finished)
    }

    /// 「続きを診断」は restart。記録がある分は診断せずに流れるので、実際に続きから走る
    @Test("中断後に続きを診断すると finished になる")
    func resumesAfterInterruption() async {
        let state = makeState(
            pixels: makePixels(),
            continuation: SpyContinuedProcessingService(expiresAfterReports: 1)
        )

        await start(state, assets: threeAssets)
        await restart(state, assets: threeAssets)

        guard case let .finished(report) = state.phase else {
            Issue.record("finished になっていない: \(state.phase)")
            return
        }
        #expect(report.diagnosed == 3)
    }
}
