//
//  ScanReportPolicyTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 結果票の数え方。総合判定は写真の枚数、表は項目ごとの枚数、顔もほかと同じ、の3点を固定する
@Suite("ScanReportPolicy")
struct ScanReportPolicyTests {
    private let sut = ScanReportPolicy()
    private let day = Date(timeIntervalSince1970: 1_750_000_000)

    private func record(
        _ id: String,
        _ outcome: ScanRecord.Outcome,
        scannedAt: Date? = nil
    ) -> ScanRecord {
        ScanRecord(
            assetID: id,
            modificationDate: nil,
            scannedAt: scannedAt ?? day,
            quality: .precise,
            generation: "test",
            outcome: outcome
        )
    }

    private func finding(_ kind: FindingKind, _ severity: Severity = .caution) -> StoredFinding {
        StoredFinding(kind: kind, severity: severity, region: .test)
    }

    private func item(_ kind: FindingKind, in report: ScanReport) -> ScanReport.Item? {
        report.items.first { $0.kind == kind }
    }

    // MARK: - 空の結果票

    @Test("何も診断していなければ、全項目が所見なしで総合判定は A")
    func emptyReport() {
        let report = sut.report(from: [])

        #expect(report.grade == .a)
        #expect(report.diagnosed == 0)
        #expect(report.lastScannedAt == nil)
        #expect(report.items.allSatisfy { $0.verdict == .clear && $0.photoCount == 0 })
    }

    /// 行が増減すると画面の表が毎回変わってしまう。種類を足したら行も足す
    @Test("表の行は全種類ぶんあり、順序が決まっている")
    func itemsCoverEveryKindInFixedOrder() {
        let kinds = sut.report(from: []).items.map(\.kind)

        #expect(kinds == ScanReportPolicy.itemOrder)
        #expect(Set(kinds) == Set(FindingKind.allCases))
        #expect(kinds.last == .bystanderFace)
    }

    // MARK: - 総合判定

    @Test("所見ゼロの写真だけなら A")
    func cleanPhotosAreGradeA() {
        let report = sut.report(from: [record("1", .scanned([])), record("2", .scanned([]))])

        #expect(report.grade == .a)
        #expect(report.diagnosed == 2)
        #expect(report.attentionPhotos == 0)
    }

    @Test("要注意の所見がある写真が1枚でもあれば B")
    func cautionMakesGradeB() {
        let report = sut.report(from: [
            record("1", .scanned([])),
            record("2", .scanned([finding(.address)]))
        ])

        #expect(report.grade == .b)
        #expect(report.cautionPhotos == 1)
        #expect(report.dangerPhotos == 0)
    }

    @Test("危険の所見がある写真が1枚でもあれば C")
    func dangerMakesGradeC() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.address)])),
            record("2", .scanned([finding(.cardNumber, .danger)]))
        ])

        #expect(report.grade == .c)
        #expect(report.dangerPhotos == 1)
        #expect(report.cautionPhotos == 1)
    }

    @Test("判定の段階は A < B < C")
    func gradesAreOrdered() {
        #expect(ScanReport.Grade.a < .b)
        #expect(ScanReport.Grade.b < .c)
        #expect(ScanReport.Grade.allCases.map(\.rawValue) == ["A", "B", "C"])
    }

    // MARK: - 写真の枚数と項目の枚数

    /// 宛名の写真は住所・電話番号・郵便番号の3項目に出る。写真としては1枚
    @Test("複数の種類が写った写真は、写真としては1回、項目にはそれぞれ数える")
    func multiKindPhotoCountsOncePerPhoto() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.address), finding(.phoneNumber), finding(.postalCode)]))
        ])

        #expect(report.cautionPhotos == 1)
        #expect(item(.address, in: report)?.photoCount == 1)
        #expect(item(.phoneNumber, in: report)?.photoCount == 1)
        #expect(item(.postalCode, in: report)?.photoCount == 1)
        #expect(item(.email, in: report)?.photoCount == 0)
    }

    @Test("同じ種類が1枚に複数あっても、その項目の枚数は1")
    func repeatedKindInOnePhotoCountsOnce() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.phoneNumber), finding(.phoneNumber)]))
        ])

        #expect(item(.phoneNumber, in: report)?.photoCount == 1)
    }

    @Test("危険と要注意が混在する写真は、危険にだけ数える")
    func mixedPhotoCountsAsDangerOnly() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.cardNumber, .danger), finding(.address)]))
        ])

        #expect(report.dangerPhotos == 1)
        #expect(report.cautionPhotos == 0)
    }

    // MARK: - 項目の判定

    @Test("項目の判定は、その種類の所見の段階で決まる")
    func itemVerdictFollowsItsOwnFindings() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.cardNumber, .danger), finding(.address)]))
        ])

        // 同じ写真でも、危険なのはカード番号だけ。住所の行まで危険にしない
        #expect(item(.cardNumber, in: report)?.verdict == .danger)
        #expect(item(.address, in: report)?.verdict == .caution)
        #expect(item(.email, in: report)?.verdict == .clear)
    }

    /// ブランド不明のカード番号は要注意。あとから危険のカード番号が来たら、その項目は危険
    @Test("項目の判定は上がるだけで、下がらない")
    func itemVerdictOnlyEscalates() {
        let cautionFirst = sut.report(from: [
            record("1", .scanned([finding(.cardNumber, .caution)])),
            record("2", .scanned([finding(.cardNumber, .danger)]))
        ])
        let dangerFirst = sut.report(from: [
            record("1", .scanned([finding(.cardNumber, .danger)])),
            record("2", .scanned([finding(.cardNumber, .caution)]))
        ])

        #expect(item(.cardNumber, in: cautionFirst)?.verdict == .danger)
        #expect(item(.cardNumber, in: dangerFirst)?.verdict == .danger)
        #expect(item(.cardNumber, in: dangerFirst)?.photoCount == 2)
    }

    // MARK: - 顔も、ほかの項目と同じ

    /// 以前は「参考」として総合判定から外していた。判定の意味が伝わらなかったので、同じ扱いにした
    @Test("顔だけの写真も、要確認として総合判定に数える")
    func faceOnlyPhotoCountsAsCaution() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.bystanderFace)])),
            record("2", .scanned([finding(.bystanderFace)]))
        ])

        #expect(report.grade == .b)
        #expect(report.cautionPhotos == 2)
        #expect(item(.bystanderFace, in: report)?.verdict == .caution)
        #expect(item(.bystanderFace, in: report)?.photoCount == 2)
    }

    @Test("顔と文字の両方が写った写真は、写真としては1回だけ数える")
    func faceWithTextCountsOnce() {
        let report = sut.report(from: [
            record("1", .scanned([finding(.bystanderFace), finding(.address)]))
        ])

        #expect(report.grade == .b)
        #expect(report.cautionPhotos == 1)
        #expect(item(.bystanderFace, in: report)?.photoCount == 1)
        #expect(item(.address, in: report)?.photoCount == 1)
    }

    // MARK: - 診断できなかった写真

    /// 見ていないものを「所見なし」に混ぜない
    @Test("診断できなかった写真は、診断済みにも所見にも数えない")
    func undiagnosedPhotosAreCountedSeparately() {
        let report = sut.report(from: [
            record("1", .scanned([])),
            record("2", .notAvailableLocally),
            record("3", .notAvailableLocally),
            record("4", .unavailableInCloud),
            record("5", .failed),
            record("6", .missing)
        ])

        #expect(report.diagnosed == 1)
        #expect(report.notAvailableLocally == 2)
        #expect(report.unavailableInCloud == 1)
        #expect(report.failed == 1)
        #expect(report.missing == 1)
        #expect(report.undiagnosed == 5)
        #expect(report.total == 6)
        #expect(report.grade == .a)
    }

    // MARK: - 日時・足し込み・消えた写真

    @Test("最後に診断した日時は、記録のうち最も新しいもの")
    func lastScannedAtIsTheLatest() {
        let later = day.addingTimeInterval(3_600)
        let report = sut.report(from: [
            record("1", .scanned([]), scannedAt: later),
            record("2", .scanned([]), scannedAt: day)
        ])

        #expect(report.lastScannedAt == later)
    }

    /// 診断中の画面は1件ずつ足す。まとめて作ったものと食い違うと、終わった瞬間に表が変わる
    @Test("1件ずつ足した結果は、まとめて作った結果と同じ")
    func incrementalMatchesBatch() {
        let records = [
            record("1", .scanned([finding(.cardNumber, .danger), finding(.address)])),
            record("2", .scanned([finding(.bystanderFace)])),
            record("3", .notAvailableLocally),
            record("4", .scanned([finding(.email), finding(.phoneNumber)])),
            record("5", .scanned([]))
        ]

        var incremental = sut.empty
        for record in records { incremental = sut.adding(record, to: incremental) }

        #expect(incremental == sut.report(from: records))
    }

    /// 写真アプリで消した写真の記録は残っている。数えると枚数が合わなくなる
    @Test("今ライブラリに無い写真の記録は数えない")
    func recordsOfDeletedPhotosAreIgnored() {
        let records = [
            record("kept", .scanned([finding(.address)])),
            record("deleted", .scanned([finding(.cardNumber, .danger)]))
        ]

        let report = sut.report(from: records, presentAssetIDs: ["kept"])

        #expect(report.diagnosed == 1)
        #expect(report.grade == .b)
        #expect(item(.cardNumber, in: report)?.photoCount == 0)
    }
}
