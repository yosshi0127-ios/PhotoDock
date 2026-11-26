//
//  ScanHomeStateTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// ホームの状態。「開いただけではアクセスを聞かない」「聞くのはボタンを押したときだけ」を固定する
@Suite("ScanHomeState")
@MainActor
struct ScanHomeStateTests {
    private func makeState(
        library: SpyPhotoLibraryService,
        records: SpyScanRecordRepository = SpyScanRecordRepository(),
        dispositions: SpyPhotoDispositionRepository = SpyPhotoDispositionRepository(),
        network: SpyNetworkStatusService = SpyNetworkStatusService(unmetered: true)
    ) -> ScanHomeState {
        withDependencies {
            $0.photoLibrary = library
            $0.scanRecords = records
            $0.photoDispositions = dispositions
            $0.network = network
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            ScanHomeState()
        }
    }

    @Test("読み込む前は loading")
    func startsLoading() {
        let state = makeState(library: SpyPhotoLibraryService(access: .full))

        #expect(state.phase == .loading)
        #expect(!state.isScanPresented)
    }

    /// 初回は約束を見せてから聞く。開いただけで確認が出てはいけない
    @Test("開いただけでは、アクセスの確認を出さない")
    func loadDoesNotPrompt() async {
        let library = SpyPhotoLibraryService(access: .notDetermined)
        let state = makeState(library: library)

        await state.load()

        #expect(state.phase == .loaded(.needsPermission))
        #expect(await library.requestAccessCallCount == 0)
        #expect(!state.isScanPresented)
    }

    @Test("初回の案内のボタンで初めてアクセスを聞き、許可されたらそのまま診断に進む")
    func allowAccessStartsScan() async {
        let assets: [AssetMetadata] = [.stub(id: "a"), .stub(id: "b")]
        let library = SpyPhotoLibraryService(access: .full, assets: assets)
        let state = makeState(library: library)

        await state.allowAccessAndStartScan()

        #expect(await library.requestAccessCallCount == 1)
        #expect(state.isScanPresented)
        #expect(state.phase == .loaded(.ready(
            ScanHomeContent(access: .full, assets: assets, report: nil, flagged: [], newPhotoCount: 2)
        )))
    }

    @Test("アクセスを断られたら、診断には進まない")
    func deniedDoesNotStartScan() async {
        let state = makeState(library: SpyPhotoLibraryService(access: .denied))

        await state.allowAccessAndStartScan()

        #expect(state.phase == .loaded(.unavailable(.denied)))
        #expect(!state.isScanPresented)
    }

    @Test("診断できる写真が無ければ、診断には進まない")
    func emptyLibraryDoesNotStartScan() async {
        let state = makeState(library: SpyPhotoLibraryService(access: .full, assets: []))

        await state.load()
        state.startScan()

        #expect(!state.isScanPresented)
    }

    @Test("読み込む前に診断を始めようとしても、何も起きない")
    func startScanBeforeLoadIsIgnored() {
        let state = makeState(library: SpyPhotoLibraryService(access: .full, assets: [.stub(id: "a")]))

        state.startScan()

        #expect(!state.isScanPresented)
    }

    /// 診断から戻ったときに結果票が更新される
    @Test("読み直すと、増えた記録が結果票に反映される")
    func reloadReflectsNewRecords() async throws {
        let finding = StoredFinding(kind: .address, severity: .caution, region: .test)
        let scanned = ScanRecord(
            assetID: "a",
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .precise,
            generation: ScanRecordPolicy().generation(osVersion: ProcessInfo.processInfo.operatingSystemVersionString),
            outcome: .scanned([finding])
        )
        let library = SpyPhotoLibraryService(access: .full, assets: [.stub(id: "a")])
        let state = makeState(library: library, records: SpyScanRecordRepository(records: [scanned]))

        await state.load()

        guard case let .loaded(.ready(content)) = state.phase else {
            Issue.record("ready にならなかった"); return
        }
        #expect(try #require(content.report).grade == .b)
        #expect(content.flagged.map(\.assetID) == ["a"])
        #expect(content.newPhotoCount == 0)
    }

    // MARK: - 項目の写真

    private func record(_ id: String, _ kinds: [FindingKind]) -> ScanRecord {
        ScanRecord(
            assetID: id,
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .precise,
            generation: ScanRecordPolicy().generation(osVersion: ProcessInfo.processInfo.operatingSystemVersionString),
            outcome: .scanned(kinds.map { StoredFinding(kind: $0, severity: .caution, region: .test) })
        )
    }

    @Test("項目の写真は、その種類が写っている写真だけ。枚数は結果票の行と同じ")
    func photosOfKindMatchReportItem() async {
        let newer = Date(timeIntervalSince1970: 1_760_000_000)
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let library = SpyPhotoLibraryService(access: .full, assets: [
            .stub(id: "old", creationDate: older), .stub(id: "new", creationDate: newer), .stub(id: "phone")
        ])
        let records = SpyScanRecordRepository(records: [
            record("old", [.address]), record("new", [.address, .phoneNumber]), record("phone", [.phoneNumber])
        ])
        let state = makeState(library: library, records: records)

        await state.load()

        // 新しい写真が先
        #expect(state.photos(of: .address).map(\.id) == ["new", "old"])
        #expect(state.photos(of: .address).first?.takenAt == newer)
        #expect(state.item(of: .address)?.photoCount == 2)
        #expect(state.item(of: .phoneNumber)?.photoCount == state.photos(of: .phoneNumber).count)
    }

    @Test("読み込む前は、項目の写真も行も無い")
    func noPhotosBeforeLoad() {
        let state = makeState(library: SpyPhotoLibraryService(access: .full))

        #expect(state.photos(of: .address).isEmpty)
        #expect(state.item(of: .address) == nil)
    }

    @Test("問題なしにした写真は、一覧で対応済みの印が付き、結果票では対応済みに数える")
    func handledPhotoIsMarked() async {
        let library = SpyPhotoLibraryService(access: .full, assets: [.stub(id: "open"), .stub(id: "done")])
        let records = SpyScanRecordRepository(records: [record("open", [.address]), record("done", [.address])])
        let dispositions = SpyPhotoDispositionRepository(dispositions: [
            PhotoDisposition(
                assetID: "done", action: .dismissed, decidedAt: Date(timeIntervalSince1970: 1_750_000_000),
                modificationDate: nil, kinds: [.address]
            )
        ])
        let state = makeState(library: library, records: records, dispositions: dispositions)

        await state.load()

        #expect(state.photos(of: .address).filter(\.isHandled).map(\.id) == ["done"])
        #expect(state.item(of: .address) == ScanReport.Item(kind: .address, verdict: .caution, photoCount: 1, handledCount: 1))
    }

    // MARK: - iCloud の写真

    /// 端末にある1枚（診断済み）と、iCloud にしか無い2枚（未診断）
    private func makeCloudState(network: SpyNetworkStatusService) -> ScanHomeState {
        func unfetched(_ id: String) -> ScanRecord {
            ScanRecord(
                assetID: id, modificationDate: nil, scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
                quality: .precise,
                generation: ScanRecordPolicy().generation(osVersion: ProcessInfo.processInfo.operatingSystemVersionString),
                outcome: .notAvailableLocally
            )
        }
        return makeState(
            library: SpyPhotoLibraryService(access: .full, assets: [.stub(id: "local"), .stub(id: "c1"), .stub(id: "c2")]),
            records: SpyScanRecordRepository(records: [record("local", []), unfetched("c1"), unfetched("c2")]),
            network: network
        )
    }

    @Test("iCloud に未診断の写真があれば、取り寄せの見積もりを出す")
    func cloudEstimateCountsUnfetched() async {
        let state = makeCloudState(network: SpyNetworkStatusService(unmetered: true))

        await state.load()

        #expect(state.cloudEstimate?.photoCount == 2)
    }

    @Test("未診断の写真が無ければ、見積もりは無く、確認の画面も出さない")
    func noCloudEstimateWithoutUnfetched() async {
        let state = makeState(
            library: SpyPhotoLibraryService(access: .full, assets: [.stub(id: "local")]),
            records: SpyScanRecordRepository(records: [record("local", [])])
        )
        await state.load()

        state.askCloudScan()

        #expect(state.cloudEstimate == nil)
        #expect(!state.isCloudConfirmPresented)
    }

    /// 数GB の通信を、確認なしに始めない
    @Test("iCloud の診断は、確認の画面を出すだけで、まだ始めない")
    func askCloudScanOnlyPresentsConfirm() async {
        let network = SpyNetworkStatusService(unmetered: true)
        let state = makeCloudState(network: network)
        await state.load()

        state.askCloudScan()

        #expect(state.isCloudConfirmPresented)
        #expect(!state.isScanPresented)
        #expect(!state.scanAllowsDownload)
        #expect(await network.callCount == 0)
    }

    @Test("Wi-Fi なら、確認の画面を閉じ、閉じ終わってから取り寄せる診断に進む")
    func confirmCloudScanStartsAfterDismiss() async {
        let state = makeCloudState(network: SpyNetworkStatusService(unmetered: true))
        await state.load()
        state.askCloudScan()

        await state.confirmCloudScan()
        #expect(!state.isCloudConfirmPresented)
        #expect(!state.isScanPresented)   // 閉じ終わるまでは進まない

        state.cloudConfirmDidDismiss()
        #expect(state.isScanPresented)
        #expect(state.scanAllowsDownload)
        // 残り時間の見積もりには、取り寄せるぶんも数える
        #expect(state.expectedToDiagnose == 2)
    }

    /// 始めてから黙って取り寄せないまま終わると、理由が分からない
    @Test("Wi-Fi でなければ、始めずに、その旨を出す")
    func confirmCloudScanStopsOffWiFi() async {
        let state = makeCloudState(network: SpyNetworkStatusService(unmetered: false))
        await state.load()
        state.askCloudScan()

        await state.confirmCloudScan()
        state.cloudConfirmDidDismiss()

        #expect(state.isOffWiFi)
        #expect(state.isCloudConfirmPresented)
        #expect(!state.isScanPresented)
        #expect(!state.scanAllowsDownload)
    }

    @Test("確認の画面を「やめる」で閉じたら、診断には進まない")
    func cancelDoesNotStart() async {
        let state = makeCloudState(network: SpyNetworkStatusService(unmetered: true))
        await state.load()
        state.askCloudScan()

        state.isCloudConfirmPresented = false
        state.cloudConfirmDidDismiss()

        #expect(!state.isScanPresented)
    }

    /// 取り寄せは、その回だけ。設定として残ると、以後の診断でも毎回数GB を取り寄せる
    @Test("取り寄せる診断のあと、ふつうの診断を始めたら、取り寄せない")
    func cloudScanIsOneShot() async {
        let state = makeCloudState(network: SpyNetworkStatusService(unmetered: true))
        await state.load()
        state.askCloudScan()
        await state.confirmCloudScan()
        state.cloudConfirmDidDismiss()
        #expect(state.scanAllowsDownload)

        state.isScanPresented = false
        state.startScan()

        #expect(state.isScanPresented)
        #expect(!state.scanAllowsDownload)
        #expect(state.expectedToDiagnose == 0)
    }
}
