//
//  ScanReportPolicy.swift
//  PhotoDock
//

import Foundation

/// スキャン済み記録 → 診断結果票。純粋関数のみ。
///
/// 1件ずつ足す形（`adding`）を基本にしてある。診断中の画面は記録が流れてくるたびに
/// 結果票を更新するので、毎回全件を数え直すと 3万枚で二乗の手間になる
struct ScanReportPolicy: Sendable {
    /// 表の行の順。危険になりうる項目を上に、参考を最後に置く
    static let itemOrder: [FindingKind] = [
        .cardNumber, .credential, .identityDocumentNumber,
        .address, .phoneNumber, .email, .postalCode,
        .bystanderFace
    ]

    /// 総合判定に数えない項目。
    /// 顔の写り込みは幾何だけの推定で外れが多く、実機では所見の8割を占めた
    /// （853枚中 51枚に所見、うち 42枚が顔）。判定に入れると顔だけで B になる
    static let referenceKinds: Set<FindingKind> = [.bystanderFace]

    /// まだ何も診断していない結果票。行は最初から全項目ぶん並べる
    var empty: ScanReport {
        ScanReport(
            diagnosed: 0,
            dangerPhotos: 0,
            cautionPhotos: 0,
            items: Self.itemOrder.map { ScanReport.Item(kind: $0, verdict: .clear, photoCount: 0) },
            notAvailableLocally: 0,
            unavailableInCloud: 0,
            failed: 0,
            missing: 0,
            lastScannedAt: nil
        )
    }

    /// 記録の一覧から結果票を作る
    func report(from records: [ScanRecord]) -> ScanReport {
        records.reduce(empty) { adding($1, to: $0) }
    }

    /// 今ライブラリにある写真の記録だけで結果票を作る。
    /// 写真アプリで消した写真の記録は残っているので、数えると枚数が合わなくなる。
    ///
    /// dispositions はユーザーが選んだ対応。対応済みの写真は危険・要確認に数えず、「対応済み」に数える。
    /// 非表示・削除した写真は今ライブラリに無いが、対応済みには数える（対応した結果として残す）
    func report(
        from records: [ScanRecord],
        presentAssetIDs: Set<String>,
        dispositions: [PhotoDisposition] = []
    ) -> ScanReport {
        let dispositionByID = Dictionary(dispositions.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })
        var report = empty

        for record in records where presentAssetIDs.contains(record.assetID) {
            let isHandled = dispositionByID[record.assetID].map {
                isActive($0, modificationDate: record.modificationDate, isPresent: true)
            } ?? false
            report = adding(record, to: report, isHandled: isHandled)
        }

        for disposition in dispositions where !presentAssetIDs.contains(disposition.assetID) {
            guard isActive(disposition, modificationDate: nil, isPresent: false) else { continue }
            addHandled(kinds: Set(disposition.kinds), to: &report)
        }

        return report
    }

    /// その対応が、今も効いているか。
    ///
    /// - 「問題なし」: 写真がライブラリにあり、決めたあとに編集されていないあいだ。
    ///   編集されたら外す（切り抜きや加工で、写っているものが変わりうる）
    /// - 非表示・削除: 写真がライブラリから見えないあいだ。
    ///   写真アプリで非表示を解除する・「最近削除した項目」から戻すと、写真がまた見えるので、未対応に戻る
    func isActive(_ disposition: PhotoDisposition, modificationDate: Date?, isPresent: Bool) -> Bool {
        switch disposition.action {
        case .dismissed: isPresent && disposition.modificationDate == modificationDate
        case .hidden, .deleted: !isPresent
        }
    }

    /// 1件ぶんを足した結果票を返す。isHandled は、その写真が対応済みか
    func adding(_ record: ScanRecord, to report: ScanReport, isHandled: Bool = false) -> ScanReport {
        var next = report
        next.lastScannedAt = max(report.lastScannedAt ?? record.scannedAt, record.scannedAt)

        switch record.outcome {
        case let .scanned(findings):
            next.diagnosed += 1
            if isHandled {
                addHandled(kinds: Set(findings.map(\.kind)), to: &next)
            } else {
                addFindings(findings, to: &next)
            }
        case .notAvailableLocally:
            next.notAvailableLocally += 1
        case .unavailableInCloud:
            next.unavailableInCloud += 1
        case .failed:
            next.failed += 1
        case .missing:
            next.missing += 1
        }

        return next
    }

    /// 対応済みの写真1枚ぶん。危険・要確認には数えず、写っていた種類それぞれの「対応済み」に数える
    private func addHandled(kinds: Set<FindingKind>, to report: inout ScanReport) {
        // 写真の枚数: 参考の項目だけの写真は、もともと総合判定に数えていないので、対応済みにも数えない
        if !kinds.isSubset(of: Self.referenceKinds) {
            report.handledPhotos += 1
        }

        for index in report.items.indices where kinds.contains(report.items[index].kind) {
            report.items[index].handledCount += 1
            // 未対応が1枚も無ければ、その項目は対応済み。あとから未対応の写真が足されれば、その判定で上書きされる
            if report.items[index].photoCount == 0 {
                report.items[index].verdict = .handled
            }
        }
    }

    private func addFindings(_ findings: [StoredFinding], to report: inout ScanReport) {
        // 写真の枚数: 参考の項目を除いた所見のうち、最も高い段階で1回だけ数える
        let judged = findings.filter { !Self.referenceKinds.contains($0.kind) }
        switch judged.highestSeverity {
        case .danger: report.dangerPhotos += 1
        case .caution: report.cautionPhotos += 1
        case nil: break
        }

        // 項目ごとの枚数: この写真に写っている種類それぞれに1枚ずつ
        for index in report.items.indices {
            let kind = report.items[index].kind
            let ofKind = findings.filter { $0.kind == kind }
            guard let severity = ofKind.highestSeverity else { continue }

            report.items[index].photoCount += 1
            report.items[index].verdict = verdict(
                for: kind, severity: severity, current: report.items[index].verdict
            )
        }
    }

    /// 未対応の写真があるあいだ、項目の判定は上がるだけ（1枚でも危険があれば、その項目は危険）。
    /// 対応済みだった項目に未対応の写真が足されたら、その写真の判定になる
    private func verdict(for kind: FindingKind, severity: Severity, current: ScanReport.Verdict) -> ScanReport.Verdict {
        if current == .danger { return .danger }
        return verdict(for: kind, severity: severity)
    }
}
