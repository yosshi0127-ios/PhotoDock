//
//  ScanReportItemPhotosTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 結果票の項目を開いたときに並ぶ写真。「表の枚数と同じ写真が、見るべき順に出る」ことを固定する
@Suite("ScanReportPolicy 項目の写真")
struct ScanReportItemPhotosTests {
    private let sut = ScanReportPolicy()
    private let day = Date(timeIntervalSince1970: 1_750_000_000)

    private func record(_ id: String, _ findings: [StoredFinding]) -> ScanRecord {
        ScanRecord(
            assetID: id, modificationDate: nil, scannedAt: day,
            quality: .precise, generation: "test", outcome: .scanned(findings)
        )
    }

    private func finding(_ kind: FindingKind, _ severity: Severity = .caution) -> StoredFinding {
        StoredFinding(kind: kind, severity: severity, region: .test)
    }

    private func asset(_ id: String, daysAgo: Double? = 0) -> AssetMetadata {
        .stub(id: id, creationDate: daysAgo.map { day.addingTimeInterval(-$0 * 86_400) })
    }

    // MARK: - どの写真が出るか

    @Test("その種類の所見がある写真だけを出す")
    func onlyPhotosWithTheKind() {
        let records = [
            record("address", [finding(.address)]),
            record("phone", [finding(.phoneNumber)]),
            record("clean", [])
        ]
        let assets = [asset("address"), asset("phone"), asset("clean")]

        let photos = sut.photos(of: .address, in: records, assets: assets)

        #expect(photos.map(\.id) == ["address"])
    }

    /// 一覧の件数が表の数字とずれると、どちらかが間違って見える
    @Test("出る枚数は、結果票の表の枚数と同じ")
    func countMatchesReportItem() {
        let records = [
            record("a", [finding(.address), finding(.phoneNumber)]),
            record("b", [finding(.address), finding(.address)]),
            record("c", [finding(.phoneNumber)])
        ]
        let assets = [asset("a"), asset("b"), asset("c")]
        let report = sut.report(from: records)

        for item in report.items {
            #expect(sut.photos(of: item.kind, in: records, assets: assets).count == item.photoCount)
        }
    }

    @Test("今ライブラリに無い写真の記録は出さない")
    func skipsRecordsWithoutAsset() {
        let records = [record("present", [finding(.address)]), record("deleted", [finding(.address)])]

        let photos = sut.photos(of: .address, in: records, assets: [asset("present")])

        #expect(photos.map(\.id) == ["present"])
    }

    @Test("診断できなかった写真は出さない", arguments: [
        ScanRecord.Outcome.notAvailableLocally, .unavailableInCloud, .missing, .failed
    ])
    func skipsUndiagnosed(_ outcome: ScanRecord.Outcome) {
        let unfetched = ScanRecord(
            assetID: "a", modificationDate: nil, scannedAt: day,
            quality: .precise, generation: "test", outcome: outcome
        )

        #expect(sut.photos(of: .address, in: [unfetched], assets: [asset("a")]).isEmpty)
    }

    // MARK: - 1枚ぶんの中身

    @Test("写っている種類は、表と同じ順で、開いている項目も含む")
    func kindsFollowTableOrder() {
        let records = [record("a", [finding(.postalCode), finding(.address), finding(.phoneNumber), finding(.address)])]

        let photo = sut.photos(of: .phoneNumber, in: records, assets: [asset("a")]).first

        #expect(photo?.kinds == [.address, .phoneNumber, .postalCode])
    }

    @Test("判定は、開いている項目の所見で決まる（ほかの種類の危険には引きずられない）")
    func verdictComesFromTheOpenedKind() {
        let records = [record("a", [finding(.cardNumber, .danger), finding(.address, .caution)])]
        let assets = [asset("a")]

        #expect(sut.photos(of: .address, in: records, assets: assets).first?.verdict == .caution)
        #expect(sut.photos(of: .cardNumber, in: records, assets: assets).first?.verdict == .danger)
    }

    @Test("同じ種類に危険と要注意があれば、高いほうを採る")
    func verdictTakesHighestSeverity() {
        let records = [record("a", [finding(.credential, .caution), finding(.credential, .danger)])]

        #expect(sut.photos(of: .credential, in: records, assets: [asset("a")]).first?.verdict == .danger)
    }

    @Test("顔の写り込みは、段階によらず参考")
    func faceIsReference() {
        let records = [record("a", [finding(.bystanderFace, .caution)])]

        #expect(sut.photos(of: .bystanderFace, in: records, assets: [asset("a")]).first?.verdict == .reference)
    }

    @Test("撮った日は写真から引く。無ければ nil")
    func takenAtComesFromAsset() {
        let records = [record("dated", [finding(.address)]), record("undated", [finding(.address)])]
        let assets = [asset("dated", daysAgo: 3), asset("undated", daysAgo: nil)]

        let photos = sut.photos(of: .address, in: records, assets: assets)

        #expect(photos.first { $0.id == "dated" }?.takenAt == day.addingTimeInterval(-3 * 86_400))
        #expect(photos.first { $0.id == "undated" }?.takenAt == nil)
    }

    // MARK: - 並び順

    @Test("危険が先、その中で新しい写真が先")
    func dangerFirstThenNewest() {
        let records = [
            record("cautionNew", [finding(.credential, .caution)]),
            record("dangerOld", [finding(.credential, .danger)]),
            record("dangerNew", [finding(.credential, .danger)]),
            record("cautionOld", [finding(.credential, .caution)])
        ]
        let assets = [
            asset("cautionNew", daysAgo: 1), asset("dangerOld", daysAgo: 30),
            asset("dangerNew", daysAgo: 2), asset("cautionOld", daysAgo: 40)
        ]

        let photos = sut.photos(of: .credential, in: records, assets: assets)

        #expect(photos.map(\.id) == ["dangerNew", "dangerOld", "cautionNew", "cautionOld"])
    }

    @Test("撮った日が分からない写真は、同じ段階の中で最後")
    func undatedComesLast() {
        let records = [record("undated", [finding(.address)]), record("old", [finding(.address)])]
        let assets = [asset("undated", daysAgo: nil), asset("old", daysAgo: 900)]

        #expect(sut.photos(of: .address, in: records, assets: assets).map(\.id) == ["old", "undated"])
    }

    /// 開くたびに順序が変わると、さっき見た写真を探し直すことになる
    @Test("段階も撮った日も同じなら、入力の順によらず同じ並びになる")
    func orderIsStable() {
        let records = [record("b", [finding(.address)]), record("a", [finding(.address)]), record("c", [finding(.address)])]
        let assets = [asset("a"), asset("b"), asset("c")]

        let forward = sut.photos(of: .address, in: records, assets: assets).map(\.id)
        let reversed = sut.photos(of: .address, in: records.reversed(), assets: assets.reversed()).map(\.id)

        #expect(forward == ["a", "b", "c"])
        #expect(reversed == forward)
    }

    // MARK: - 写真詳細の所見

    @Test("写真詳細の所見は種類ごとに1行。表と同じ順で、場所の数を持つ")
    func findingsAreGroupedByKind() {
        let photo = record("a", [
            finding(.postalCode), finding(.address), finding(.cardNumber, .danger), finding(.address)
        ])

        #expect(sut.findings(in: photo) == [
            ReportPhotoFinding(kind: .cardNumber, verdict: .danger, placeCount: 1),
            ReportPhotoFinding(kind: .address, verdict: .caution, placeCount: 2),
            ReportPhotoFinding(kind: .postalCode, verdict: .caution, placeCount: 1)
        ])
    }

    @Test("同じ種類に危険と要注意があれば、その行は危険")
    func findingRowTakesHighestSeverity() {
        let photo = record("a", [finding(.credential, .caution), finding(.credential, .danger)])

        #expect(sut.findings(in: photo) == [ReportPhotoFinding(kind: .credential, verdict: .danger, placeCount: 2)])
    }

    @Test("顔の写り込みの行は参考")
    func faceRowIsReference() {
        let photo = record("a", [finding(.bystanderFace), finding(.bystanderFace)])

        #expect(sut.findings(in: photo) == [ReportPhotoFinding(kind: .bystanderFace, verdict: .reference, placeCount: 2)])
    }

    @Test("所見が無い写真・診断できなかった写真は、行が無い")
    func noRowsWithoutFindings() {
        let unfetched = ScanRecord(
            assetID: "a", modificationDate: nil, scannedAt: day,
            quality: .precise, generation: "test", outcome: .notAvailableLocally
        )

        #expect(sut.findings(in: record("a", [])).isEmpty)
        #expect(sut.findings(in: unfetched).isEmpty)
    }
}
