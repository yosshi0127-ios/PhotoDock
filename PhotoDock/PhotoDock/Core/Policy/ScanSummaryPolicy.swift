//
//  ScanSummaryPolicy.swift
//  PhotoDock
//

/// 全量スキャンの集計。1件ずつ足していく純粋関数。
/// 一括で配列を受け取らないのは、全量スキャンが数分〜数十分かかるため
/// （終わるまで待つと進捗が出せない）。記録から復元した分も新しく診断した分も同じ形で足せる。
struct ScanSummaryPolicy: Sendable {
    func adding(_ record: ScanRecord, to summary: ScanSummary) -> ScanSummary {
        var next = summary

        switch record.outcome {
        case let .scanned(findings):
            next.scanned += 1

            // 1枚は1つの区分にだけ数える（両方に数えると合計が枚数を超える）
            switch findings.highestSeverity {
            case .danger: next.dangerPhotos += 1
            case .caution: next.cautionPhotos += 1
            case nil: break   // 所見ゼロ。診断はできたのでどこにも数えない
            }

        case .notAvailableLocally:
            next.notAvailableLocally += 1

        case .unavailableInCloud:
            next.unavailableInCloud += 1

        case .missing:
            next.missing += 1
        }

        return next
    }
}
