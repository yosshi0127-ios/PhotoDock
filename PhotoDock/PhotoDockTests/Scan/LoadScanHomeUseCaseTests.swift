//
//  LoadScanHomeUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// ホームを開いたときの読み込み。「ダイアログを出さない」ことと、
/// 結果票に数える記録・「新しい写真」に数える写真の選び方を固定する
@Suite("LoadScanHomeUseCase")
struct LoadScanHomeUseCaseTests {
    private let generation = ScanRecordPolicy().generation(
        osVersion: ProcessInfo.processInfo.operatingSystemVersionString
    )

    private func record(
        _ id: String,
        _ outcome: ScanRecord.Outcome = .scanned([]),
        modificationDate: Date? = nil,
        generation: String? = nil
    ) -> ScanRecord {
        ScanRecord(
            assetID: id,
            modificationDate: modificationDate,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .precise,
            generation: generation ?? self.generation,
            outcome: outcome
        )
    }

    private func load(
        library: SpyPhotoLibraryService,
        records: SpyScanRecordRepository = SpyScanRecordRepository(),
        dispositions: SpyPhotoDispositionRepository = SpyPhotoDispositionRepository()
    ) async -> ScanHomeSnapshot {
        await withDependencies {
            $0.photoLibrary = library
            $0.scanRecords = records
            $0.photoDispositions = dispositions
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = LoadScanHomeUseCase()
            return await useCase(quality: .precise)
        }
    }

    // MARK: - 許可の状態

    /// 初回は約束を見せてから聞く。ここで聞いてしまうと、案内の前にダイアログが出る
    @Test("まだアクセスを聞いていなければ、ダイアログを出さず、写真も読まない")
    func doesNotPromptWhenNotDetermined() async {
        let library = SpyPhotoLibraryService(access: .notDetermined)

        let snapshot = await load(library: library)

        #expect(snapshot == .needsPermission)
        #expect(await library.requestAccessCallCount == 0)
        #expect(await library.fetchCallCount == 0)
    }

    @Test("拒否・機能制限なら、その状態を返して写真は読まない", arguments: [
        PhotoLibraryAccess.denied, .restricted
    ])
    func unavailableWhenDeniedOrRestricted(_ access: PhotoLibraryAccess) async {
        let library = SpyPhotoLibraryService(access: access)

        let snapshot = await load(library: library)

        #expect(snapshot == .unavailable(access))
        #expect(await library.fetchCallCount == 0)
    }

    @Test("許可済みでも、アクセスの確認ダイアログは出さない", arguments: [
        PhotoLibraryAccess.full, .limited
    ])
    func neverPromptsWhenAuthorized(_ access: PhotoLibraryAccess) async {
        let library = SpyPhotoLibraryService(access: access, assets: [.stub(id: "a")])

        _ = await load(library: library)

        #expect(await library.requestAccessCallCount == 0)
    }

    // MARK: - 結果票

    @Test("まだ1枚も診断していなければ、結果票は無く、全部が新しい写真")
    func noReportBeforeFirstScan() async {
        let assets: [AssetMetadata] = [.stub(id: "a"), .stub(id: "b"), .stub(id: "c")]
        let library = SpyPhotoLibraryService(access: .full, assets: assets)

        let snapshot = await load(library: library)

        #expect(snapshot == .ready(ScanHomeContent(access: .full, assets: assets, report: nil, flagged: [], newPhotoCount: 3)))
    }

    @Test("記録があれば、今ある写真の記録から結果票を作る")
    func buildsReportFromRecords() async throws {
        let assets: [AssetMetadata] = [.stub(id: "a"), .stub(id: "b")]
        let finding = StoredFinding(kind: .address, severity: .caution, region: .test)
        let records = SpyScanRecordRepository(records: [record("a", .scanned([finding])), record("b")])

        let snapshot = await load(library: SpyPhotoLibraryService(access: .full, assets: assets), records: records)

        guard case let .ready(content) = snapshot else {
            Issue.record("ready にならなかった"); return
        }
        let unwrapped = try #require(content.report)
        #expect(unwrapped.diagnosed == 2)
        #expect(unwrapped.grade == .b)
        #expect(content.newPhotoCount == 0)
        // 所見のある写真だけが一覧に回る
        #expect(content.flagged.map(\.assetID) == ["a"])
    }

    /// 写真アプリで消した写真の記録は残っている。結果票に数えると枚数が合わなくなる
    @Test("ライブラリから消えた写真の記録は、結果票に数えない")
    func ignoresRecordsOfDeletedPhotos() async throws {
        let danger = StoredFinding(kind: .cardNumber, severity: .danger, region: .test)
        let records = SpyScanRecordRepository(records: [record("kept"), record("deleted", .scanned([danger]))])
        let library = SpyPhotoLibraryService(access: .full, assets: [.stub(id: "kept")])

        guard case let .ready(content) = await load(library: library, records: records) else {
            Issue.record("ready にならなかった"); return
        }
        let unwrapped = try #require(content.report)
        #expect(unwrapped.diagnosed == 1)
        #expect(unwrapped.grade == .a)
        #expect(content.flagged.isEmpty)
    }

    /// 記録はキャッシュ。読めなくても診断はできる（全件を診断し直せば元に戻る）
    @Test("記録を読めなければ、まだ診断していない状態として扱う")
    func treatsUnreadableRecordsAsNone() async {
        let assets: [AssetMetadata] = [.stub(id: "a"), .stub(id: "b")]
        let library = SpyPhotoLibraryService(access: .full, assets: assets)

        let snapshot = await load(library: library, records: SpyScanRecordRepository(failsOnLoad: true))

        #expect(snapshot == .ready(ScanHomeContent(access: .full, assets: assets, report: nil, flagged: [], newPhotoCount: 2)))
    }

    // MARK: - 新しい写真の枚数

    @Test("記録の無い写真・編集された写真・診断の世代が古い写真を、新しい写真として数える")
    func countsNewPhotos() async {
        let edited = Date(timeIntervalSince1970: 1_760_000_000)
        let assets: [AssetMetadata] = [
            .stub(id: "scanned"),
            .stub(id: "noRecord"),
            .stub(id: "edited", modificationDate: edited),
            .stub(id: "oldRules")
        ]
        let records = SpyScanRecordRepository(records: [
            record("scanned"),
            record("edited", modificationDate: nil),
            record("oldRules", generation: "old")
        ])

        let snapshot = await load(library: SpyPhotoLibraryService(access: .full, assets: assets), records: records)

        guard case let .ready(content) = snapshot else {
            Issue.record("ready にならなかった"); return
        }
        #expect(content.newPhotoCount == 3)
    }

    /// iCloud にあって取れなかった写真は毎回試すが、「新しい写真」ではない。
    /// 数えると、2,000枚がいつまでも「新しい写真」として表示される
    @Test("取れなかった写真は、新しい写真に数えない", arguments: [
        ScanRecord.Outcome.notAvailableLocally, .unavailableInCloud, .failed, .missing
    ])
    func doesNotCountUnfetchedAsNew(_ outcome: ScanRecord.Outcome) async {
        let records = SpyScanRecordRepository(records: [record("a", outcome)])
        let library = SpyPhotoLibraryService(access: .full, assets: [.stub(id: "a")])

        guard case let .ready(content) = await load(library: library, records: records) else {
            Issue.record("ready にならなかった"); return
        }
        #expect(content.newPhotoCount == 0)
        // 結果票には「未診断」として載る
        #expect(content.report?.undiagnosed == 1)
    }

    /// 実機で起きた: 判定ルールを変えたら、ボタンが「3,053 枚を診断する」になった（診断できるのは 880枚ほど）
    @Test("判定ルールが変わっても、取れなかった写真は新しい写真に数えない")
    func doesNotCountUnfetchedAsNewAfterRulesChange() async {
        let assets: [AssetMetadata] = [.stub(id: "local"), .stub(id: "cloud1"), .stub(id: "cloud2")]
        let records = SpyScanRecordRepository(records: [
            record("local", generation: "old"),
            record("cloud1", .notAvailableLocally, generation: "old"),
            record("cloud2", .notAvailableLocally, generation: "old")
        ])

        guard case let .ready(content) = await load(
            library: SpyPhotoLibraryService(access: .full, assets: assets), records: records
        ) else {
            Issue.record("ready にならなかった"); return
        }
        // 診断し直すのは、端末にあって前回診断できた1枚だけ
        #expect(content.newPhotoCount == 1)
        #expect(content.pendingCount(allowsDownload: false) == 1)
        // 取り寄せを許可していれば、iCloud のぶんも診断する
        #expect(content.pendingCount(allowsDownload: true) == 3)
    }

    // MARK: - 対応状況

    @Test("対応済みの写真は、結果票で要確認に数えず、対応済みに数える")
    func appliesDispositions() async {
        let assets: [AssetMetadata] = [.stub(id: "open"), .stub(id: "dismissed")]
        let address = StoredFinding(kind: .address, severity: .caution, region: .test)
        let records = SpyScanRecordRepository(records: [
            record("open", .scanned([address])), record("dismissed", .scanned([address]))
        ])
        let dispositions = SpyPhotoDispositionRepository(dispositions: [
            PhotoDisposition(
                assetID: "dismissed", action: .dismissed, decidedAt: Date(timeIntervalSince1970: 1_750_000_000),
                modificationDate: nil, kinds: [.address]
            ),
            // 非表示にした写真は、もうライブラリに無い
            PhotoDisposition(
                assetID: "hidden", action: .hidden, decidedAt: Date(timeIntervalSince1970: 1_750_000_000),
                modificationDate: nil, kinds: [.address]
            )
        ])

        guard case let .ready(content) = await load(
            library: SpyPhotoLibraryService(access: .full, assets: assets), records: records, dispositions: dispositions
        ) else {
            Issue.record("ready にならなかった"); return
        }
        #expect(content.report?.cautionPhotos == 1)
        #expect(content.report?.handledPhotos == 2)
        #expect(content.report?.grade == .b)
    }

    /// 対応状況が読めないからといって、所見まで出せなくなってはいけない
    @Test("対応状況が読めなければ、まだ何も対応していないものとして結果票を出す")
    func showsReportWhenDispositionsFail() async {
        let address = StoredFinding(kind: .address, severity: .caution, region: .test)
        let records = SpyScanRecordRepository(records: [record("a", .scanned([address]))])

        guard case let .ready(content) = await load(
            library: SpyPhotoLibraryService(access: .full, assets: [.stub(id: "a")]),
            records: records,
            dispositions: SpyPhotoDispositionRepository(failsOnLoad: true)
        ) else {
            Issue.record("ready にならなかった"); return
        }
        #expect(content.report?.cautionPhotos == 1)
        #expect(content.report?.handledPhotos == 0)
    }
}
