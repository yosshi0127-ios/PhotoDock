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
        ScanRecord.Outcome.missing
    ])
    func unavailableOutcomeIsRetried(_ outcome: ScanRecord.Outcome) {
        #expect(sut.needsRescan(record: record(outcome: outcome), asset: asset(), quality: .quick, generation: generation))
    }
}
