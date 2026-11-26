//
//  ScanReportDispositionTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 対応（問題なし・非表示・削除）を入れた結果票の数え方。
/// 「対応すると判定が上がる」「対応が外れる条件」を固定する
@Suite("ScanReportPolicy 対応済み")
struct ScanReportDispositionTests {
    private let sut = ScanReportPolicy()
    private let day = Date(timeIntervalSince1970: 1_750_000_000)
    private let edited = Date(timeIntervalSince1970: 1_760_000_000)

    private func record(_ id: String, _ findings: [StoredFinding], modificationDate: Date? = nil) -> ScanRecord {
        ScanRecord(
            assetID: id, modificationDate: modificationDate, scannedAt: day,
            quality: .precise, generation: "test", outcome: .scanned(findings)
        )
    }

    private func finding(_ kind: FindingKind, _ severity: Severity = .caution) -> StoredFinding {
        StoredFinding(kind: kind, severity: severity, region: .test)
    }

    private func disposition(
        _ id: String, _ action: PhotoDisposition.Action, kinds: [FindingKind] = [], modificationDate: Date? = nil
    ) -> PhotoDisposition {
        PhotoDisposition(assetID: id, action: action, decidedAt: day, modificationDate: modificationDate, kinds: kinds)
    }

    private func item(_ kind: FindingKind, in report: ScanReport) -> ScanReport.Item? {
        report.items.first { $0.kind == kind }
    }

    // MARK: - 問題なしにする

    @Test("問題なしにした写真は、要確認に数えず、対応済みに数える")
    func dismissedIsHandled() {
        let records = [record("a", [finding(.address)]), record("b", [finding(.address)])]

        let report = sut.report(from: records, presentAssetIDs: ["a", "b"], dispositions: [disposition("a", .dismissed)])

        #expect(report.cautionPhotos == 1)
        #expect(report.handledPhotos == 1)
        #expect(item(.address, in: report) == ScanReport.Item(kind: .address, verdict: .caution, photoCount: 1, handledCount: 1))
        // 診断した枚数は変わらない
        #expect(report.diagnosed == 2)
    }

    @Test("すべて対応すると、項目は対応済みになり、総合判定が上がる")
    func allHandledRaisesGrade() {
        let records = [record("a", [finding(.cardNumber, .danger)]), record("b", [finding(.address)])]
        let present: Set<String> = ["a", "b"]

        #expect(sut.report(from: records, presentAssetIDs: present).grade == .c)

        let afterDanger = sut.report(from: records, presentAssetIDs: present, dispositions: [disposition("a", .dismissed)])
        #expect(afterDanger.grade == .b)
        #expect(item(.cardNumber, in: afterDanger)?.verdict == .handled)

        let afterAll = sut.report(
            from: records, presentAssetIDs: present,
            dispositions: [disposition("a", .dismissed), disposition("b", .dismissed)]
        )
        #expect(afterAll.grade == .a)
        #expect(afterAll.handledPhotos == 2)
        #expect(item(.address, in: afterAll) == ScanReport.Item(kind: .address, verdict: .handled, photoCount: 0, handledCount: 1))
    }

    @Test("未対応の写真が1枚でも残っていれば、項目は対応済みにならない（記録の順によらない）")
    func itemStaysOpenWhileAnyUnhandled() {
        let handledFirst = [record("handled", [finding(.address)]), record("open", [finding(.address)])]
        let dispositions = [disposition("handled", .dismissed)]
        let present: Set<String> = ["handled", "open"]

        let forward = sut.report(from: handledFirst, presentAssetIDs: present, dispositions: dispositions)
        let reversed = sut.report(from: handledFirst.reversed(), presentAssetIDs: present, dispositions: dispositions)

        #expect(item(.address, in: forward)?.verdict == .caution)
        #expect(item(.address, in: reversed)?.verdict == .caution)
    }

    @Test("複数の種類が写った写真を対応すると、それぞれの項目の対応済みに数える")
    func handledCountsEveryKind() {
        let records = [record("a", [finding(.address), finding(.phoneNumber), finding(.address)])]

        let report = sut.report(from: records, presentAssetIDs: ["a"], dispositions: [disposition("a", .dismissed)])

        #expect(item(.address, in: report)?.handledCount == 1)
        #expect(item(.phoneNumber, in: report)?.handledCount == 1)
        #expect(report.handledPhotos == 1)
    }

    /// 切り抜きや加工で、写っているものが変わりうる
    @Test("問題なしにしたあとで写真が編集されたら、未対応に戻る")
    func dismissedIsDroppedAfterEdit() {
        let records = [record("a", [finding(.address)], modificationDate: edited)]

        let report = sut.report(
            from: records, presentAssetIDs: ["a"],
            dispositions: [disposition("a", .dismissed, modificationDate: nil)]
        )

        #expect(report.cautionPhotos == 1)
        #expect(report.handledPhotos == 0)
    }

    @Test("顔だけの写真を対応したら、ほかの写真と同じく対応済みに数える")
    func handledFaceOnlyIsCounted() {
        let records = [record("a", [finding(.bystanderFace)])]

        let report = sut.report(from: records, presentAssetIDs: ["a"], dispositions: [disposition("a", .dismissed)])

        #expect(report.handledPhotos == 1)
        #expect(report.grade == .a)
        #expect(item(.bystanderFace, in: report) == ScanReport.Item(
            kind: .bystanderFace, verdict: .handled, photoCount: 0, handledCount: 1
        ))
    }

    // MARK: - 非表示・削除

    /// 非表示・削除した写真はアプリから見えない。記録からではなく、対応に残した種類で数える
    @Test("非表示・削除した写真は、ライブラリに無くても対応済みに数える", arguments: [
        PhotoDisposition.Action.hidden, .deleted
    ])
    func absentHandledIsCounted(_ action: PhotoDisposition.Action) {
        let records = [record("kept", [finding(.address)])]

        let report = sut.report(
            from: records, presentAssetIDs: ["kept"],
            dispositions: [disposition("gone", action, kinds: [.address, .phoneNumber])]
        )

        #expect(report.handledPhotos == 1)
        #expect(item(.address, in: report) == ScanReport.Item(kind: .address, verdict: .caution, photoCount: 1, handledCount: 1))
        #expect(item(.phoneNumber, in: report) == ScanReport.Item(kind: .phoneNumber, verdict: .handled, photoCount: 0, handledCount: 1))
        // 今ライブラリに無いので、診断した枚数には入らない
        #expect(report.diagnosed == 1)
    }

    /// 写真アプリで非表示を解除する・「最近削除した項目」から戻すと、写真がまた見える
    @Test("非表示・削除した写真がライブラリに戻ってきたら、未対応に戻る", arguments: [
        PhotoDisposition.Action.hidden, .deleted
    ])
    func restoredPhotoIsOpenAgain(_ action: PhotoDisposition.Action) {
        let records = [record("back", [finding(.address)])]

        let report = sut.report(
            from: records, presentAssetIDs: ["back"],
            dispositions: [disposition("back", action, kinds: [.address])]
        )

        #expect(report.cautionPhotos == 1)
        #expect(report.handledPhotos == 0)
        #expect(item(.address, in: report)?.handledCount == 0)
    }

    /// 自分で写真アプリから消した写真。もう無いので、どこにも数えない
    @Test("問題なしにした写真がライブラリから無くなったら、対応済みにも数えない")
    func dismissedAbsentIsNotCounted() {
        let report = sut.report(
            from: [], presentAssetIDs: [],
            dispositions: [disposition("gone", .dismissed, kinds: [.address])]
        )

        #expect(report == sut.empty)
    }

    // MARK: - 対応が無いとき

    @Test("対応が1件も無ければ、これまでの結果票と同じ")
    func noDispositionsChangesNothing() {
        let records = [
            record("a", [finding(.cardNumber, .danger), finding(.address)]),
            record("b", [finding(.bystanderFace)]),
            record("c", [])
        ]

        #expect(sut.report(from: records, presentAssetIDs: ["a", "b", "c"]) == sut.report(from: records))
    }

    // MARK: - 非表示・削除した写真の一覧

    private func removed(
        _ id: String, _ action: PhotoDisposition.Action, kinds: [FindingKind], decidedDaysLater: Double = 0, takenAt: Date? = nil
    ) -> PhotoDisposition {
        PhotoDisposition(
            assetID: id, action: action, decidedAt: day.addingTimeInterval(decidedDaysLater * 86_400),
            modificationDate: nil, kinds: kinds, takenAt: takenAt
        )
    }

    /// 写真はもう読めない。対処の記録に残したことだけで、1枚ずつ行にする
    @Test("非表示・削除した写真を、その種類が写っていたものだけ、対処した日の新しい順に返す")
    func removedPhotosOfKind() {
        let taken = day.addingTimeInterval(-86_400 * 30)
        let dispositions = [
            removed("old", .hidden, kinds: [.postalCode, .address], decidedDaysLater: 1, takenAt: taken),
            removed("new", .deleted, kinds: [.address], decidedDaysLater: 2),
            removed("other", .deleted, kinds: [.cardNumber], decidedDaysLater: 3)
        ]

        let photos = sut.removedPhotos(of: .address, dispositions: dispositions, presentAssetIDs: [])

        #expect(photos.map(\.assetID) == ["new", "old"])
        #expect(photos.map(\.action) == [.deleted, .hidden])
        // 写っていた種類は、表と同じ順
        #expect(photos.last?.kinds == [.address, .postalCode])
        #expect(photos.last?.takenAt == taken)
        // この項目を足す前に対処した写真は、撮った日が無い
        #expect(photos.first?.takenAt == nil)
    }

    @Test("問題なしにした写真と、ライブラリに戻ってきた写真は、非表示・削除の一覧に出さない")
    func removedPhotosExcludesDismissedAndRestored() {
        let dispositions = [
            removed("dismissed", .dismissed, kinds: [.address]),
            removed("restored", .hidden, kinds: [.address]),
            removed("gone", .hidden, kinds: [.address])
        ]

        let photos = sut.removedPhotos(of: .address, dispositions: dispositions, presentAssetIDs: ["dismissed", "restored"])

        #expect(photos.map(\.assetID) == ["gone"])
    }

    /// 一覧の枚数と、結果票の「対応済み」の数字がずれないこと
    @Test("非表示・削除の一覧と、問題なしの写真を足すと、結果票の対応済みの枚数になる")
    func removedCountMatchesReport() {
        let records = [record("open", [finding(.address)]), record("dismissed", [finding(.address)])]
        let dispositions = [
            disposition("dismissed", .dismissed),
            removed("hidden", .hidden, kinds: [.address]),
            removed("deleted", .deleted, kinds: [.address, .phoneNumber])
        ]
        let present: Set<String> = ["open", "dismissed"]

        let report = sut.report(from: records, presentAssetIDs: present, dispositions: dispositions)
        let removedPhotos = sut.removedPhotos(of: .address, dispositions: dispositions, presentAssetIDs: present)

        #expect(item(.address, in: report)?.handledCount == 1 + removedPhotos.count)
    }
}
