//
//  ScanSummaryPolicy.swift
//  PhotoDock
//

/// 全量スキャンの集計。1枚ずつ足していく純粋関数。
/// 一括で配列を受け取らないのは、全量スキャンが数分〜数十分かかるため
/// （終わるまで待つと進捗が出せない）。
struct ScanSummaryPolicy: Sendable {
    func adding(_ photo: ScannedPhoto, to summary: ScanSummary) -> ScanSummary {
        var next = summary

        switch photo.outcome {
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

        case .missing:
            next.missing += 1
        }

        return next
    }
}
