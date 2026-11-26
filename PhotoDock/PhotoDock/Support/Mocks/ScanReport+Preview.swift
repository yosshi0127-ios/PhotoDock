//
//  ScanReport+Preview.swift
//  PhotoDock
//

import Foundation

/// Preview 用の結果票。数字は実機の結果（2026-11-20・853枚）に合わせてある。
/// 日時は固定（Date.now を使うと Preview が毎回変わる）
extension ScanReport {
    private static let scannedAt = Date(timeIntervalSince1970: 1_763_600_000)

    private static func make(
        diagnosed: Int,
        danger: Int,
        caution: Int,
        notAvailableLocally: Int,
        counts: [FindingKind: (ScanReport.Verdict, Int)]
    ) -> ScanReport {
        ScanReport(
            diagnosed: diagnosed,
            dangerPhotos: danger,
            cautionPhotos: caution,
            items: ScanReportPolicy.itemOrder.map { kind in
                let (verdict, count) = counts[kind] ?? (.clear, 0)
                return ScanReport.Item(kind: kind, verdict: verdict, photoCount: count)
            },
            notAvailableLocally: notAvailableLocally,
            unavailableInCloud: 0,
            failed: 0,
            missing: 0,
            lastScannedAt: scannedAt
        )
    }

    /// 総合判定 B。文字の所見 9枚・顔 42枚（重なりなし）・iCloud に 2,198枚
    static let previewCaution = make(
        diagnosed: 853, danger: 0, caution: 51, notAvailableLocally: 2_198,
        counts: [
            .credential: (.caution, 1), .address: (.caution, 3), .phoneNumber: (.caution, 5),
            .email: (.caution, 5), .postalCode: (.caution, 3), .bystanderFace: (.caution, 42)
        ]
    )

    /// 総合判定 C。カード番号と認証情報に危険がある
    static let previewDanger = make(
        diagnosed: 1_204, danger: 3, caution: 70, notAvailableLocally: 0,
        counts: [
            .cardNumber: (.danger, 2), .credential: (.danger, 1), .address: (.caution, 4),
            .phoneNumber: (.caution, 6), .email: (.caution, 5), .bystanderFace: (.caution, 58)
        ]
    )

    /// 総合判定 A。所見なし
    static let previewClear = make(
        diagnosed: 853, danger: 0, caution: 0, notAvailableLocally: 0,
        counts: [:]
    )
}
