//
//  ScanSummaryView.swift
//  PhotoDock
//

import SwiftUI

/// 第1段スキャンの集計。入力を受け取るだけなので、状態ごとに Preview を並べられる。
struct ScanSummaryView: View {
    let inventory: LibraryInventory
    let access: PhotoLibraryAccess

    var body: some View {
        VStack(spacing: 24) {
            total

            VStack {
                LabeledContent("位置情報付き") {
                    Text(inventory.withLocation.formatted())
                        .monospacedDigit()
                }
                LabeledContent("スクリーンショット") {
                    Text(inventory.screenshots.formatted())
                        .monospacedDigit()
                }
            }

            if access == .limited {
                limitedNotice
            }
        }
    }

    /// 数字と単位を1つの要素として読ませる（分かれていると VoiceOver が別々に読む）
    private var total: some View {
        VStack {
            Text(inventory.total.formatted())
                .font(.largeTitle)
                .bold()
                .monospacedDigit()
            Text("枚の写真を確認しました")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var limitedNotice: some View {
        Text("選択された写真だけを診断しています。すべてを診断するには、写真へのフルアクセスを許可してください。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview("フルアクセス") {
    ScanSummaryView(
        inventory: LibraryInventory(total: 1_240, withLocation: 310, screenshots: 486),
        access: .full
    )
    .padding()
}

#Preview("一部のみ許可") {
    ScanSummaryView(
        inventory: LibraryInventory(total: 12, withLocation: 3, screenshots: 4),
        access: .limited
    )
    .padding()
}

#Preview("0枚") {
    ScanSummaryView(
        inventory: LibraryInventory(total: 0, withLocation: 0, screenshots: 0),
        access: .full
    )
    .padding()
}
