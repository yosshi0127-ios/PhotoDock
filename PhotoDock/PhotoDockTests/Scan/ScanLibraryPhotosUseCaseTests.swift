//
//  ScanLibraryPhotosUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 全量スキャン（第2段）。診断の中身は 1枚経路のテストが持つので、
/// ここでは「取りこぼさないこと」「並列数を守ること」「記録で診断を省くこと」を見る。
@Suite("ScanLibraryPhotosUseCase")
struct ScanLibraryPhotosUseCaseTests {
    private let generation = ProcessInfo.processInfo.operatingSystemVersionString

    private func assets(_ count: Int) -> [AssetMetadata] {
        (0..<count).map { .stub(id: "asset-\($0)") }
    }

    /// 現在の OS・クイック・未編集で診断済みの記録（= 有効）
    private func validRecord(_ id: String, findings: [StoredFinding] = []) -> ScanRecord {
        ScanRecord(
            assetID: id,
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .quick,
            generation: generation,
            outcome: .scanned(findings)
        )
    }

    private func scanAll(
        _ assets: [AssetMetadata],
        concurrency: Int = 2,
        pixels: any PixelSourceService,
        ocr: SpyOCRService = SpyOCRService(),
        records: SpyScanRecordRepository = SpyScanRecordRepository()
    ) async -> [ScanRecord] {
        await withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = records
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanLibraryPhotosUseCase()

            var scanned: [ScanRecord] = []
            for await record in useCase(assets: assets, quality: .quick, concurrency: concurrency) {
                scanned.append(record)
            }
            return scanned
        }
    }

    // MARK: - 取りこぼし・並列

    @Test("渡した枚数だけ、過不足なく流れる")
    func scansEveryAsset() async {
        let targets = assets(20)

        let records = await scanAll(targets, concurrency: 4, pixels: ConcurrencyProbePixelSourceService())

        #expect(records.count == targets.count)
        // 完了順なので入力順とは限らない。取りこぼしと重複だけを見る
        #expect(Set(records.map(\.assetID)) == Set(targets.map(\.id)))
    }

    /// 並列数の制御は「全部直列」でも「制限を超えて全部同時」でも結果は正しく出る。
    /// 実行の重なり方を測らないと壊れていることに気づけない
    @Test("同時実行数が concurrency を超えない")
    func respectsConcurrencyLimit() async {
        let probe = ConcurrencyProbePixelSourceService(delay: .milliseconds(10))

        _ = await scanAll(assets(20), concurrency: 3, pixels: probe)

        #expect(await probe.maxConcurrent <= 3)
        // 直列に落ちていないことも確認する（1 なら並列化が効いていない）
        #expect(await probe.maxConcurrent > 1)
    }

    /// 0 を渡すと最初の1枚も走らず、1件も処理しないまま正常終了しかねない
    @Test("concurrency が 0 でも全件処理する", arguments: [0, -1, 1])
    func survivesInvalidConcurrency(_ concurrency: Int) async {
        let records = await scanAll(assets(5), concurrency: concurrency, pixels: ConcurrencyProbePixelSourceService())

        #expect(records.count == 5)
    }

    @Test("空のライブラリでは何も流れずに終わる")
    func emptyLibraryFinishes() async {
        let records = await scanAll([], pixels: ConcurrencyProbePixelSourceService())

        #expect(records.isEmpty)
    }

    /// 1枚の失敗で全体を止めない。iCloud 上の写真も結果として流す
    @Test("取得できない写真も結果として流れる")
    func reportsUnavailablePhotos() async {
        let pixels = ConcurrencyProbePixelSourceService(outcome: .notAvailableLocally)

        let records = await scanAll(assets(5), pixels: pixels)

        #expect(records.count == 5)
        #expect(records.allSatisfy { $0.outcome == .notAvailableLocally })
    }

    /// 消費側がやめても裏で走り続けると、画面を閉じた後も3万枚を処理してしまう
    @Test("途中でやめたら残りはスキャンされない")
    func cancellationStopsScanning() async throws {
        let probe = ConcurrencyProbePixelSourceService(delay: .milliseconds(20))

        await withDependencies {
            $0.pixelSource = probe
            $0.ocr = SpyOCRService()
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = SpyScanRecordRepository()
        } operation: {
            let useCase = ScanLibraryPhotosUseCase()

            var count = 0
            for await _ in useCase(assets: assets(200), quality: .quick, concurrency: 2) {
                count += 1
                if count == 5 { break }
            }
        }

        // 何枚目で止まるかはタイミング次第なので、件数ではなく「止まったこと」を見る
        try await Task.sleep(for: .milliseconds(200))
        let afterLeaving = await probe.callCount
        try await Task.sleep(for: .milliseconds(200))
        let later = await probe.callCount

        #expect(afterLeaving < 200)
        // 待っても増えない = 完全に止まっている
        #expect(afterLeaving == later)
    }

    // MARK: - 記録による短縮

    /// 2回目以降の短縮の正体。ここが壊れると3万枚が毎回全部回る
    @Test("有効な記録がある写真は診断せず、記録をそのまま流す")
    func reusesValidRecords() async {
        let targets = assets(5)
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))
        let existing = targets.prefix(3).map { validRecord($0.id) }

        let records = await scanAll(targets, pixels: pixels, records: SpyScanRecordRepository(records: existing))

        #expect(records.count == 5)
        // 記録が無い2枚だけが pixelSource に届く
        #expect(Set(await pixels.requestedIDs) == ["asset-3", "asset-4"])
    }

    @Test("記録が古ければ（要求が高品質）診断し直す")
    func rescansStaleRecords() async {
        let targets = assets(2)
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))
        let stale = targets.map { validRecord($0.id) }   // quick で診断済み

        _ = await withDependencies {
            $0.pixelSource = pixels
            $0.ocr = SpyOCRService()
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = SpyScanRecordRepository(records: stale)
        } operation: {
            let useCase = ScanLibraryPhotosUseCase()
            var records: [ScanRecord] = []
            for await record in useCase(assets: targets, quality: .precise) { records.append(record) }
            return records
        }

        #expect(await pixels.requestedIDs.count == 2)
    }

    @Test("診断した写真は1枚ずつ記録に保存される")
    func savesEachScannedPhoto() async {
        let repo = SpyScanRecordRepository()
        let targets = assets(4)

        let records = await scanAll(targets, pixels: ConcurrencyProbePixelSourceService(), records: repo)

        let saved = await repo.saved
        #expect(saved.count == 4)
        #expect(Set(saved.map(\.assetID)) == Set(targets.map(\.id)))
        #expect(saved.allSatisfy { $0.quality == .quick && $0.generation == generation })
        // 流れたものと保存したものは同じ内容
        #expect(Set(records.map(\.assetID)) == Set(saved.map(\.assetID)))
    }

    @Test("記録から流した分は保存し直さない")
    func doesNotResaveReusedRecords() async {
        let repo = SpyScanRecordRepository(records: assets(3).map { validRecord($0.id) })

        _ = await scanAll(assets(3), pixels: SpyPixelSourceService(outcome: .data(Data("image".utf8))), records: repo)

        #expect(await repo.saved.isEmpty)
    }

    /// 保存の失敗でスキャンを止めない。その写真は次回また診断されるだけ
    @Test("保存に失敗してもスキャンは続き、結果は流れる")
    func continuesWhenSaveFails() async {
        let repo = SpyScanRecordRepository(failsOnSave: true)

        let records = await scanAll(assets(5), pixels: ConcurrencyProbePixelSourceService(), records: repo)

        #expect(records.count == 5)
    }

    /// 読めなかったときに全件を「未スキャン」として扱う（キャッシュなので壊れない）
    @Test("記録が読めなければ全件診断する")
    func scansEverythingWhenLoadFails() async {
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))
        let repo = SpyScanRecordRepository(records: assets(3).map { validRecord($0.id) }, failsOnLoad: true)

        let records = await scanAll(assets(3), pixels: pixels, records: repo)

        #expect(records.count == 3)
        #expect(await pixels.requestedIDs.count == 3)
    }
}
