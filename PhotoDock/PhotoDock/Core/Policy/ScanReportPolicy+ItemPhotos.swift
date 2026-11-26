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
    /// assets は撮った日を引くためだけに使う。assets に無い記録（写真アプリで消した写真）は出さない。
    /// dispositions があれば、対応済みの写真に印を付ける（並び順は変えない。分けて見せるのは画面の役目）
    func photos(
        of kind: FindingKind,
        in records: [ScanRecord],
        assets: [AssetMetadata],
        dispositions: [PhotoDisposition] = []
    ) -> [ReportItemPhoto] {
        let assetByID = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let dispositionByID = Dictionary(dispositions.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })

        let photos: [ReportItemPhoto] = records.compactMap { record in
            guard let asset = assetByID[record.assetID] else { return nil }
            let ofKind = record.findings.filter { $0.kind == kind }
            guard let severity = ofKind.highestSeverity else { return nil }

            let present = Set(record.findings.map(\.kind))
            return ReportItemPhoto(
                record: record,
                takenAt: asset.creationDate,
                verdict: verdict(for: kind, severity: severity),
                kinds: Self.itemOrder.filter(present.contains),
                isHandled: dispositionByID[record.assetID].map {
                    isActive($0, modificationDate: record.modificationDate, isPresent: true)
                } ?? false
            )
        }

        return photos.sorted(by: Self.comesFirst)
    }

    /// その写真に付ける対応を組み立てる。写っていた種類は、表と同じ順で残す
    func disposition(
        _ action: PhotoDisposition.Action,
        for record: ScanRecord,
        takenAt: Date? = nil,
        decidedAt: Date
    ) -> PhotoDisposition {
        let present = Set(record.findings.map(\.kind))
        return PhotoDisposition(
            assetID: record.assetID,
            action: action,
            decidedAt: decidedAt,
            modificationDate: record.modificationDate,
            kinds: Self.itemOrder.filter(present.contains),
            takenAt: takenAt
        )
    }

    /// 結果票の項目を開いたときに、対応済みの側に並べる「非表示・削除した写真」。
    ///
    /// - その種類が写っていて、いまライブラリから見えない写真だけ（写真アプリで戻した写真は、未対応に戻る）
    /// - **対処した日の新しい順**（いま対処したものが上に来る）。同じ日時なら ID の順
    func removedPhotos(
        of kind: FindingKind,
        dispositions: [PhotoDisposition],
        presentAssetIDs: Set<String>
    ) -> [ReportRemovedPhoto] {
        dispositions
            .filter { disposition in
                disposition.action != .dismissed
                    && disposition.kinds.contains(kind)
                    && isActive(disposition, modificationDate: nil, isPresent: presentAssetIDs.contains(disposition.assetID))
            }
            .map { disposition in
                ReportRemovedPhoto(
                    assetID: disposition.assetID,
                    action: disposition.action,
                    takenAt: disposition.takenAt,
                    decidedAt: disposition.decidedAt,
                    kinds: Self.itemOrder.filter(disposition.kinds.contains)
                )
            }
            .sorted { lhs, rhs in
                lhs.decidedAt != rhs.decidedAt ? lhs.decidedAt > rhs.decidedAt : lhs.assetID < rhs.assetID
            }
    }

    /// 写真詳細に出す所見。種類ごとに1行にまとめ、結果票の表と同じ順に並べる。
    /// 診断できなかった写真は空
    func findings(in record: ScanRecord) -> [ReportPhotoFinding] {
        Self.itemOrder.compactMap { kind in
            let ofKind = record.findings.filter { $0.kind == kind }
            guard let severity = ofKind.highestSeverity else { return nil }
            return ReportPhotoFinding(
                kind: kind,
                verdict: verdict(for: kind, severity: severity),
                placeCount: ofKind.count
            )
        }
    }

    /// 項目の中での1枚の判定。どの種類も、所見の段階で決まる
    func verdict(for kind: FindingKind, severity: Severity) -> ScanReport.Verdict {
        severity == .danger ? .danger : .caution
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
