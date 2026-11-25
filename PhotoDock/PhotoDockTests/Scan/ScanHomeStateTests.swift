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
        records: SpyScanRecordRepository = SpyScanRecordRepository()
    ) -> ScanHomeState {
        withDependencies {
            $0.photoLibrary = library
            $0.scanRecords = records
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
}
