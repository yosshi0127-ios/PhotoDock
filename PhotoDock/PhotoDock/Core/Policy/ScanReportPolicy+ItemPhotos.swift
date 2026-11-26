//
//  ScanReportPolicy+ItemPhotos.swift
//  PhotoDock
//

import Foundation

extension ScanReportPolicy {
    /// 結果票の項目を開いたときに並べる写真。純粋関数。
    ///
    /// - その種類の所見がある写真だけを出す（表の「枚数」と同じ数になる）
    /// - **危険が先、その中で新しい写真が先**。先に見るべきものを上に置く。
    ///   撮った日が分からない写真は最後。それでも並びが決まらなければ ID の順（開くたびに順序が変わらないように）
    ///
    /// assets は撮った日を引くためだけに使う。assets に無い記録（写真アプリで消した写真）は出さない
    func photos(of kind: FindingKind, in records: [ScanRecord], assets: [AssetMetadata]) -> [ReportItemPhoto] {
        let assetByID = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let photos: [ReportItemPhoto] = records.compactMap { record in
            guard let asset = assetByID[record.assetID] else { return nil }
            let ofKind = record.findings.filter { $0.kind == kind }
            guard let severity = ofKind.highestSeverity else { return nil }

            let present = Set(record.findings.map(\.kind))
            return ReportItemPhoto(
                record: record,
                takenAt: asset.creationDate,
                verdict: verdict(for: kind, severity: severity),
                kinds: Self.itemOrder.filter(present.contains)
            )
        }

        return photos.sorted(by: Self.comesFirst)
    }

    /// 項目の中での1枚の判定。参考の項目は、段階によらず参考
    func verdict(for kind: FindingKind, severity: Severity) -> ScanReport.Verdict {
        if Self.referenceKinds.contains(kind) { return .reference }
        return severity == .danger ? .danger : .caution
    }

    private static func comesFirst(_ lhs: ReportItemPhoto, _ rhs: ReportItemPhoto) -> Bool {
        let lhsDanger = lhs.verdict == .danger
        let rhsDanger = rhs.verdict == .danger
        if lhsDanger != rhsDanger { return lhsDanger }

        switch (lhs.takenAt, rhs.takenAt) {
        case let (left?, right?) where left != right: return left > right
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.record.assetID < rhs.record.assetID
        }
    }
}
