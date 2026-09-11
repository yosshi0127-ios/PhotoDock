//
//  InMemoryScanRecordRepository.swift
//  PhotoDock
//

import Foundation

/// Preview 用のメモリ上の記録。SwiftData には触らない。
/// allRecords は assetID 順に返す（辞書の順序はプロセスごとに変わるので、Preview の表示が揺れないように）。
actor InMemoryScanRecordRepository: ScanRecordRepository {
    private var storage: [String: ScanRecord]

    init(records: [ScanRecord] = []) {
        storage = Dictionary(uniqueKeysWithValues: records.map { ($0.assetID, $0) })
    }

    func allRecords() -> [ScanRecord] {
        storage.values.sorted { $0.assetID < $1.assetID }
    }

    func save(_ record: ScanRecord) {
        storage[record.assetID] = record
    }

    func deleteAll() {
        storage.removeAll()
    }
}

extension InMemoryScanRecordRepository {
    /// Preview で「前回の診断結果がある」状態を成立させる種。
    /// assetID は StubPixelSourceService が画像を描く id に合わせる（一覧でサムネイルが出る）。
    /// 日時は固定（Date.now を使うと Preview が毎回変わる）
    static let previewSeed: [ScanRecord] = {
        let scannedAt = Date(timeIntervalSince1970: 1_757_000_000)
        let full = Region(x: 0.1, y: 0.2, width: 0.6, height: 0.08)

        return [
            ScanRecord(
                assetID: "stub-0", modificationDate: nil, scannedAt: scannedAt, quality: .quick, generation: "preview",
                outcome: .scanned([StoredFinding(kind: .cardNumber, severity: .danger, region: full)])
            ),
            ScanRecord(
                assetID: "stub-7", modificationDate: nil, scannedAt: scannedAt, quality: .quick, generation: "preview",
                outcome: .scanned([StoredFinding(kind: .phoneNumber, severity: .caution, region: full)])
            ),
            ScanRecord(
                assetID: "stub-14", modificationDate: nil, scannedAt: scannedAt, quality: .quick, generation: "preview",
                outcome: .scanned([StoredFinding(kind: .email, severity: .caution, region: full)])
            ),
            ScanRecord(
                assetID: "stub-1", modificationDate: nil, scannedAt: scannedAt, quality: .quick, generation: "preview",
                outcome: .scanned([])
            ),
            ScanRecord(
                assetID: "stub-3", modificationDate: nil, scannedAt: scannedAt, quality: .quick, generation: "preview",
                outcome: .notAvailableLocally
            )
        ]
    }()
}
