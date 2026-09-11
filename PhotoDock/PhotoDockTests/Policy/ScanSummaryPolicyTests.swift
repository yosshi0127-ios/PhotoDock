//
//  ScanSummaryPolicyTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

@Suite("ScanSummaryPolicy")
struct ScanSummaryPolicyTests {
    private let sut = ScanSummaryPolicy()

    private func record(_ id: String, _ outcome: ScanRecord.Outcome) -> ScanRecord {
        ScanRecord(
            assetID: id,
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .quick,
            generation: "test",
            outcome: outcome
        )
    }

    private func finding(_ severity: Severity) -> StoredFinding {
        StoredFinding(kind: .address, severity: severity, region: .test)
    }

    /// 「診断できた」と「危険だった」を混ぜない
    @Test("所見ゼロの写真は scanned に数えるが flagged には数えない")
    func safePhotoCountsAsScannedOnly() {
        let summary = sut.adding(record("1", .scanned([])), to: .empty)

        #expect(summary.scanned == 1)
        #expect(summary.flaggedPhotos == 0)
        #expect(summary.completed == 1)
    }

    @Test("危険な所見のある写真は dangerPhotos に数える")
    func dangerPhoto() {
        let summary = sut.adding(record("1", .scanned([finding(.danger)])), to: .empty)

        #expect(summary.scanned == 1)
        #expect(summary.dangerPhotos == 1)
        #expect(summary.cautionPhotos == 0)
    }

    /// 両方に数えると dangerPhotos + cautionPhotos が写真の枚数を超える
    @Test("危険と要注意が混在する写真は danger にだけ数える")
    func mixedSeverityCountsOnceAsDanger() {
        let mixed = ScanRecord.Outcome.scanned([finding(.caution), finding(.danger), finding(.caution)])

        let summary = sut.adding(record("1", mixed), to: .empty)

        #expect(summary.dangerPhotos == 1)
        #expect(summary.cautionPhotos == 0)
        #expect(summary.flaggedPhotos == summary.scanned)
    }

    @Test("要注意だけの写真は cautionPhotos に数える")
    func cautionOnlyPhoto() {
        let summary = sut.adding(record("1", .scanned([finding(.caution), finding(.caution)])), to: .empty)

        #expect(summary.cautionPhotos == 1)
        #expect(summary.dangerPhotos == 0)
    }

    /// 診断できなかったものを「安全」に混ぜない
    @Test("取得できなかった写真は scanned に数えない", arguments: [
        ScanRecord.Outcome.notAvailableLocally,
        ScanRecord.Outcome.missing
    ])
    func unavailablePhotoIsNotScanned(_ outcome: ScanRecord.Outcome) {
        let summary = sut.adding(record("1", outcome), to: .empty)

        #expect(summary.scanned == 0)
        #expect(summary.completed == 1)
    }

    @Test("足し込みが累積する")
    func accumulates() {
        var summary = ScanSummary.empty

        summary = sut.adding(record("1", .scanned([finding(.danger)])), to: summary)
        summary = sut.adding(record("2", .scanned([finding(.caution)])), to: summary)
        summary = sut.adding(record("3", .scanned([])), to: summary)
        summary = sut.adding(record("4", .notAvailableLocally), to: summary)
        summary = sut.adding(record("5", .missing), to: summary)

        #expect(summary.scanned == 3)
        #expect(summary.notAvailableLocally == 1)
        #expect(summary.missing == 1)
        #expect(summary.dangerPhotos == 1)
        #expect(summary.cautionPhotos == 1)
        #expect(summary.completed == 5)
        #expect(summary.flaggedPhotos == 2)
    }
}
