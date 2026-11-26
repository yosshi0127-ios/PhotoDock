//
//  ReportItemPhoto+Preview.swift
//  PhotoDock
//

import Foundation

/// Preview 用の、項目の一覧の行。日時は固定（Date.now を使うと Preview が毎回変わる）
extension ReportItemPhoto {
    private static let day = Date(timeIntervalSince1970: 1_763_600_000)
    private static let region = Region(x: 0.1, y: 0.2, width: 0.6, height: 0.08)

    private static func make(
        _ id: String, daysAgo: Double?, verdict: ScanReport.Verdict, kinds: [FindingKind]
    ) -> ReportItemPhoto {
        ReportItemPhoto(
            record: ScanRecord(
                assetID: id, modificationDate: nil, scannedAt: day, quality: .precise, generation: "preview",
                outcome: .scanned(kinds.map { StoredFinding(kind: $0, severity: .caution, region: region) })
            ),
            takenAt: daysAgo.map { day.addingTimeInterval(-$0 * 86_400) },
            verdict: verdict,
            kinds: kinds
        )
    }

    static let previewAddress = [
        make("stub-0", daysAgo: 48, verdict: .caution, kinds: [.address, .phoneNumber, .postalCode]),
        make("stub-7", daysAgo: 91, verdict: .caution, kinds: [.address, .phoneNumber, .email]),
        make("stub-14", daysAgo: nil, verdict: .caution, kinds: [.address, .postalCode])
    ]

    static let previewCredential = [
        make("stub-21", daysAgo: 3, verdict: .danger, kinds: [.credential]),
        make("stub-28", daysAgo: 200, verdict: .caution, kinds: [.credential, .email])
    ]
}
