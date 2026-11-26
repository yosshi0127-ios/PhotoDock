//
//  ScanRecordPolicyTests.swift
//  PhotoDockTests
//

import Foundation
import Testing
@testable import PhotoDock

/// 「記録を信じてよいか」の判定。ここが甘いと古い判定を信じ続け、厳しいと2回目以降の短縮が消える
@Suite("ScanRecordPolicy")
struct ScanRecordPolicyTests {
    private let sut = ScanRecordPolicy()
    private let edited = Date(timeIntervalSince1970: 1_700_000_000)
    private let generation = "iOS 18.4"

    private func record(
        quality: ScanQuality = .quick,
        generation: String? = nil,
        modificationDate: Date? = nil,
        outcome: ScanRecord.Outcome = .scanned([])
    ) -> ScanRecord {
        ScanRecord(
            assetID: "asset",
            modificationDate: modificationDate,
            scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: quality,
            generation: generation ?? self.generation,
            outcome: outcome
        )
    }

    private func asset(modificationDate: Date? = nil) -> AssetMetadata {
        .stub(id: "asset", modificationDate: modificationDate)
    }

    @Test("記録が無ければ診断する")
    func noRecord() {
        #expect(sut.needsRescan(record: nil, asset: asset(), quality: .quick, generation: generation))
    }

    /// これが false にならないと、カメラロールの大半（何も無い写真）が毎回再スキャンされる
    @Test("同じ条件で診断済みなら記録を使う")
    func validRecordIsReused() {
        #expect(!sut.needsRescan(record: record(), asset: asset(), quality: .quick, generation: generation))
    }

    @Test("写真が編集されていたら診断し直す")
    func editedPhotoIsRescanned() {
        let stale = record(modificationDate: nil)

        #expect(sut.needsRescan(record: stale, asset: asset(modificationDate: edited), quality: .quick, generation: generation))
    }

    @Test("要求が記録より高品質なら診断し直す")
    func higherQualityRequestRescans() {
        #expect(sut.needsRescan(record: record(quality: .quick), asset: asset(), quality: .precise, generation: generation))
    }

    /// 高品質側が常に勝つ。精密で診断済みの写真をクイックで回し直す理由はない
    @Test("記録が要求より高品質なら記録を使う")
    func higherQualityRecordIsReused() {
        #expect(!sut.needsRescan(record: record(quality: .precise), asset: asset(), quality: .quick, generation: generation))
    }

    /// 半年に一度の利用だと、前回と今回の間に OS のメジャー更新が挟まるのが普通
    @Test("OS（Vision の世代）が変わっていたら診断し直す")
    func newGenerationRescans() {
        #expect(sut.needsRescan(record: record(generation: "iOS 18.4"), asset: asset(), quality: .quick, generation: "iOS 19.0"))
    }

    /// 前回 iCloud 上にあった写真が今回は端末に来ているかもしれない。取得の失敗は一瞬なので毎回試す
    @Test("取れなかった記録は毎回再挑戦する", arguments: [
        ScanRecord.Outcome.notAvailableLocally,
        ScanRecord.Outcome.unavailableInCloud,
        ScanRecord.Outcome.missing,
        ScanRecord.Outcome.failed     // 文字を読めなかった。診断の事実ではないのでやり直す
    ])
    func unavailableOutcomeIsRetried(_ outcome: ScanRecord.Outcome) {
        #expect(sut.needsRescan(record: record(outcome: outcome), asset: asset(), quality: .quick, generation: generation))
    }

    // MARK: - まだ診断していない写真（ホームの「新しい写真」）

    @Test("記録が無い・編集された・品質が低い・世代が違う写真は、まだ診断していない写真")
    func outdatedRecords() {
        #expect(sut.isOutdated(record: nil, asset: asset(), quality: .quick, generation: generation))
        #expect(sut.isOutdated(record: record(), asset: asset(modificationDate: edited), quality: .quick, generation: generation))
        #expect(sut.isOutdated(record: record(quality: .quick), asset: asset(), quality: .precise, generation: generation))
        #expect(sut.isOutdated(record: record(generation: "old"), asset: asset(), quality: .quick, generation: generation))
        #expect(!sut.isOutdated(record: record(), asset: asset(), quality: .quick, generation: generation))
    }

    /// needsRescan は true（毎回試す）だが、「新しい写真」には数えない
    @Test("取れなかった記録は診断し直すが、まだ診断していない写真には数えない", arguments: [
        ScanRecord.Outcome.notAvailableLocally,
        ScanRecord.Outcome.unavailableInCloud,
        ScanRecord.Outcome.missing,
        ScanRecord.Outcome.failed
    ])
    func unfetchedIsRetriedButNotOutdated(_ outcome: ScanRecord.Outcome) {
        let unfetched = record(outcome: outcome)

        #expect(sut.needsRescan(record: unfetched, asset: asset(), quality: .quick, generation: generation))
        #expect(!sut.isOutdated(record: unfetched, asset: asset(), quality: .quick, generation: generation))
    }

    /// 判定ルールを変えた直後だけ、iCloud の 2,000枚が「新しい写真」に戻っていた
    @Test("取れなかった記録は、世代・品質・編集日時が変わっても、まだ診断していない写真に数えない", arguments: [
        ScanRecord.Outcome.notAvailableLocally,
        ScanRecord.Outcome.unavailableInCloud,
        ScanRecord.Outcome.missing,
        ScanRecord.Outcome.failed
    ])
    func unfetchedIsNeverOutdated(_ outcome: ScanRecord.Outcome) {
        let oldGeneration = record(generation: "old", outcome: outcome)
        let lowQuality = record(quality: .quick, outcome: outcome)

        #expect(!sut.isOutdated(record: oldGeneration, asset: asset(), quality: .quick, generation: generation))
        #expect(!sut.isOutdated(record: lowQuality, asset: asset(), quality: .precise, generation: generation))
        #expect(!sut.isOutdated(record: record(outcome: outcome), asset: asset(modificationDate: edited), quality: .quick, generation: generation))
        // 診断し直すことは変わらない
        #expect(sut.needsRescan(record: oldGeneration, asset: asset(), quality: .quick, generation: generation))
    }

    // MARK: - 世代（OS の版 + 判定ルールの版）

    @Test("世代は OS の版と判定ルールの版の両方を含む")
    func generationContainsBothVersions() {
        #expect(sut.generation(osVersion: "Version 26.2", rulesVersion: 3) == "Version 26.2#rules3")
        // 省略時は今の判定ルールの版
        #expect(sut.generation(osVersion: "Version 26.2")
            == sut.generation(osVersion: "Version 26.2", rulesVersion: FindingRules.version))
    }

    /// 判定ルールを直したのに古い判定が記録に残り続ける、を防ぐ
    @Test("判定ルールの版が変わっていたら診断し直す")
    func rulesVersionChangeTriggersRescan() {
        let old = sut.generation(osVersion: "Version 26.2", rulesVersion: 1)
        let new = sut.generation(osVersion: "Version 26.2", rulesVersion: 2)

        #expect(sut.needsRescan(record: record(generation: old), asset: asset(), quality: .quick, generation: new))
        #expect(!sut.needsRescan(record: record(generation: new), asset: asset(), quality: .quick, generation: new))
    }

    /// 版を入れる前の記録（OS の版だけ）は、今の世代と一致しないので診断し直される
    @Test("判定ルールの版を持たない古い記録は診断し直す")
    func recordWithoutRulesVersionIsRescanned() {
        let osOnly = "Version 26.2"
        let current = sut.generation(osVersion: osOnly)

        #expect(sut.needsRescan(record: record(generation: osOnly), asset: asset(), quality: .quick, generation: current))
    }
}
