//
//  ScanLibraryPhotosUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 全量スキャン（第2段）。診断の中身は 1枚経路のテストが持つので、
/// ここでは「取りこぼさないこと」「並列数を守ること」「記録で診断を省くこと」
/// 「ダウンロードの許可が正しく経路を通ること」を見る。
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
        quality: ScanQuality = .quick,
        allowsDownload: Bool = false,
        concurrency: Int = 2,
        pixels: any PixelSourceService,
        ocr: SpyOCRService = SpyOCRService(),
        records: SpyScanRecordRepository = SpyScanRecordRepository(),
        network: SpyNetworkStatusService = SpyNetworkStatusService(unmetered: false),
        continuation: SpyContinuedProcessingService = SpyContinuedProcessingService()
    ) async -> [ScanRecord] {
        await withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = records
            $0.network = network
            $0.continuedProcessing = continuation
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanLibraryPhotosUseCase()

            var scanned: [ScanRecord] = []
            for await record in useCase(
                assets: assets, quality: quality, allowsDownload: allowsDownload, concurrency: concurrency
            ) {
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
            $0.network = SpyNetworkStatusService(unmetered: false)
            $0.continuedProcessing = SpyContinuedProcessingService()
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

        _ = await scanAll(targets, quality: .precise, pixels: pixels, records: SpyScanRecordRepository(records: stale))

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

    // MARK: - iCloud のダウンロード

    /// 既定はオフ。オフなら回線を見にも行かない（ユーザーの回線を勝手に使わない）
    @Test("ダウンロード許可がオフなら端末のみで取り、回線も見ない")
    func downloadDisabledStaysLocal() async {
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))
        let network = SpyNetworkStatusService(unmetered: true)

        _ = await scanAll(assets(3), allowsDownload: false, pixels: pixels, network: network)

        #expect(await pixels.requestedModes.allSatisfy { $0 == .localOnly })
        #expect(await network.callCount == 0)
    }

    /// 縮小版は要求品質の解像度で取る（それ以上取っても OCR で縮めるだけ）
    @Test("許可がオンで Wi-Fi なら、要求品質の解像度で縮小版を取る")
    func downloadsOnUnmeteredNetwork() async {
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))

        _ = await scanAll(
            assets(3), quality: .precise, allowsDownload: true,
            pixels: pixels, network: SpyNetworkStatusService(unmetered: true)
        )

        let expected = PixelFetchMode.downloadIfNeeded(maxPixelSize: ScanQuality.precise.maxPixelSize)
        #expect(await pixels.requestedModes.allSatisfy { $0 == expected })
    }

    /// 「Wi-Fi 接続時のみ」の担保。許可があってもモバイル回線では通信しない
    @Test("許可がオンでも従量課金の回線なら端末のみ")
    func staysLocalOnMeteredNetwork() async {
        let pixels = SpyPixelSourceService(outcome: .data(Data("image".utf8)))
        let network = SpyNetworkStatusService(unmetered: false)

        _ = await scanAll(assets(3), allowsDownload: true, pixels: pixels, network: network)

        #expect(await pixels.requestedModes.allSatisfy { $0 == .localOnly })
        // 回線の判定はスキャン開始時に1回だけ
        #expect(await network.callCount == 1)
    }

    // MARK: - バックグラウンド継続

    /// アプリを離れても診断が続く根拠。申告しないと数秒でサスペンドされる
    @Test("診断する写真があれば継続を申告し、全件流し終えたら成功で閉じる")
    func beginsContinuationAndEndsWithSuccess() async {
        let spy = SpyContinuedProcessingService()

        let records = await scanAll(assets(5), pixels: ConcurrencyProbePixelSourceService(), continuation: spy)

        #expect(records.count == 5)
        #expect(await spy.begun == [ContinuedWork(title: "写真を診断しています", subtitle: "0 / 5 枚", totalUnits: 5)])
        #expect(await spy.ended == [true])
    }

    /// OS は進捗が進まないタスクを優先的に打ち切る。1枚ごとに報告していることを固定する
    @Test("進捗は1枚ごとに報告され、最後は全件になる")
    func reportsProgressPerPhoto() async {
        let spy = SpyContinuedProcessingService()

        _ = await scanAll(assets(5), pixels: ConcurrencyProbePixelSourceService(), continuation: spy)

        let reports = await spy.reports
        #expect(reports.map(\.completedUnits) == [1, 2, 3, 4, 5])
        #expect(reports.last?.subtitle == "5 / 5 枚")
    }

    /// 進捗の分母は全件。記録で済んだ分は申告の時点で完了に数える（画面のヘッダと同じ数字）
    @Test("記録で済んだ分は申告前に完了として数える")
    func countsReusedRecordsBeforeBeginning() async {
        let targets = assets(5)
        let spy = SpyContinuedProcessingService()
        let existing = targets.prefix(3).map { validRecord($0.id) }

        _ = await scanAll(
            targets, pixels: SpyPixelSourceService(outcome: .data(Data("image".utf8))),
            records: SpyScanRecordRepository(records: existing), continuation: spy
        )

        #expect(await spy.begun.first?.subtitle == "3 / 5 枚")
        #expect(await spy.reports.map(\.completedUnits) == [4, 5])
    }

    /// 1秒で終わる処理を申告すると Live Activity が一瞬出て消えるだけになる
    @Test("全件が記録で済むなら申告しない")
    func skipsContinuationWhenNothingToScan() async {
        let spy = SpyContinuedProcessingService()
        let repo = SpyScanRecordRepository(records: assets(3).map { validRecord($0.id) })

        let records = await scanAll(
            assets(3), pixels: SpyPixelSourceService(outcome: .data(Data("image".utf8))),
            records: repo, continuation: spy
        )

        #expect(records.count == 3)
        #expect(await spy.begun.isEmpty)
        #expect(await spy.ended.isEmpty)
    }

    /// 申告は延命であって処理の開始条件ではない
    @Test("申告できない環境でも診断は全件進む")
    func scansWithoutContinuation() async {
        let spy = SpyContinuedProcessingService(isSupported: false)

        let records = await scanAll(assets(5), pixels: ConcurrencyProbePixelSourceService(), continuation: spy)

        #expect(records.count == 5)
        #expect(await spy.ended.isEmpty)
    }

    /// ユーザーが Live Activity から中止したら、それ以上診断を積まない。打ち切りは失敗として閉じる
    @Test("OS に打ち切られたら残りは診断されず、失敗で閉じる")
    func expirationStopsScanning() async throws {
        let probe = ConcurrencyProbePixelSourceService()
        let spy = SpyContinuedProcessingService(expiresAfterReports: 3)

        let records = await scanAll(assets(50), concurrency: 2, pixels: probe, continuation: spy)

        // 3枚目の報告の直後に止まる。流れた分と OS への報告の順序は決まっている（end → finish）
        #expect(records.count == 3)
        #expect(await spy.ended == [false])

        // 待っても増えない = 完全に止まっている
        let afterStop = await probe.callCount
        try await Task.sleep(for: .milliseconds(100))
        #expect(afterStop < 50)
        #expect(await probe.callCount == afterStop)
    }

    /// 画面を離れて止めたときも、OS に「終わった」と伝えないと Live Activity が残る
    @Test("消費側が途中でやめたら失敗で閉じる")
    func consumerLeavingEndsWithFailure() async throws {
        let spy = SpyContinuedProcessingService()

        await withDependencies {
            $0.pixelSource = ConcurrencyProbePixelSourceService()
            $0.ocr = SpyOCRService()
            $0.faceDetection = SpyFaceDetectionService()
            $0.scanRecords = SpyScanRecordRepository()
            $0.network = SpyNetworkStatusService(unmetered: false)
            $0.continuedProcessing = spy
        } operation: {
            let useCase = ScanLibraryPhotosUseCase()

            var count = 0
            for await _ in useCase(assets: assets(20), quality: .quick, concurrency: 2) {
                count += 1
                if count == 3 { break }
            }
        }

        // 離脱後の end は走っていた分が終わってから届くので、少し待つ
        try await Task.sleep(for: .milliseconds(200))
        #expect(await spy.ended == [false])
    }
}
