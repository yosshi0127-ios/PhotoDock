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

            // ダウンロードを試しても iCloud 側に実体が無かった写真。ユーザーにできることは無いので
            // 「未診断」と混ぜず、原因が分かる名前で出す
            if summary.unavailableInCloud > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("iCloud から取り出せない") {
                        Text(summary.unavailableInCloud.formatted())
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Text("iCloud 上にデータが見つからない写真です。写真アプリでも開けないことがあります。")
                        .font(.footnote)
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

#Preview("iCloud から取り出せない写真がある") {
    ScanCountsView(summary: ScanSummary(
        scanned: 3_340, notAvailableLocally: 0, unavailableInCloud: 9, missing: 0, dangerPhotos: 5, cautionPhotos: 37
    ))
    .padding()
}
