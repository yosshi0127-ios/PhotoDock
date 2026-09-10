//
//  ScanCountsView.swift
//  PhotoDock
//

import SwiftUI

/// 診断結果の内訳。スキャン中は増えていき、完了後はそのまま最終結果になる。
struct ScanCountsView: View {
    let summary: ScanSummary

    var body: some View {
        VStack(spacing: 8) {
            LabeledContent("危険") {
                Text(summary.dangerPhotos.formatted())
                    .monospacedDigit()
                    .foregroundStyle(Severity.danger.tint)
            }

            LabeledContent("要注意") {
                Text(summary.cautionPhotos.formatted())
                    .monospacedDigit()
                    .foregroundStyle(Severity.caution.tint)
            }

            // 0件のときに出すと「iCloud のせいで診断できていない」と不安にさせる
            if summary.notAvailableLocally > 0 {
                LabeledContent("iCloud にあり未診断") {
                    Text(summary.notAvailableLocally.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("スキャン中") {
    ScanCountsView(summary: ScanSummary(
        scanned: 820, notAvailableLocally: 12, missing: 0, dangerPhotos: 3, cautionPhotos: 47
    ))
    .padding()
}

#Preview("所見なし") {
    ScanCountsView(summary: ScanSummary(
        scanned: 1_240, notAvailableLocally: 0, missing: 0, dangerPhotos: 0, cautionPhotos: 0
    ))
    .padding()
}
