//
//  FullScanHeader.swift
//  PhotoDock
//

import SwiftUI

/// 全量スキャンの画面で上に固定する部分。進捗（完了後は結果）と1行の要約だけに絞り、
/// 下に増えていく写真のグリッドを圧迫しない。詳細な内訳は完了後に本文側へ。
struct FullScanHeader: View {
    let phase: FullScanState.Phase
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch phase {
            case .idle:
                ProgressView()

            case let .scanning(summary):
                progress(summary)
                compactCounts(summary)

            case let .finished(summary):
                result(summary)
                compactCounts(summary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)   // 固定中に下のグリッドが透けないように
    }

    private func progress(_ summary: ScanSummary) -> some View {
        // total が 0 でも割り算が壊れないように下限を 1 にする
        ProgressView(value: Double(summary.completed), total: Double(max(1, total))) {
            Text("写真を診断しています")
        } currentValueLabel: {
            Text("\(summary.completed.formatted()) / \(total.formatted()) 枚")
                .monospacedDigit()
        }
    }

    /// 検出は原理的に不完全なので、ゼロ件でも「安全です」とは言わない
    @ViewBuilder
    private func result(_ summary: ScanSummary) -> some View {
        if summary.flaggedPhotos == 0 {
            Label("見られたらまずい情報は見つかりませんでした", systemImage: "checkmark.circle")
        } else {
            Label("\(summary.flaggedPhotos.formatted()) 枚に所見があります", systemImage: "exclamationmark.circle")
        }
    }

    /// 危険・要注意・未診断を1行で
    private func compactCounts(_ summary: ScanSummary) -> some View {
        HStack(spacing: 16) {
            Label("\(Severity.danger.label) \(summary.dangerPhotos.formatted())", systemImage: Severity.danger.icon)
                .foregroundStyle(Severity.danger.tint)
            Label("\(Severity.caution.label) \(summary.cautionPhotos.formatted())", systemImage: Severity.caution.icon)
                .foregroundStyle(Severity.caution.tint)

            let undiagnosed = summary.notAvailableLocally + summary.unavailableInCloud
            if undiagnosed > 0 {
                Label("未診断 \(undiagnosed.formatted())", systemImage: "icloud.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }
}

#Preview("診断中") {
    FullScanHeader(
        phase: .scanning(ScanSummary(scanned: 820, notAvailableLocally: 12, missing: 0, dangerPhotos: 3, cautionPhotos: 47)),
        total: 3_357
    )
}

#Preview("完了・所見なし") {
    FullScanHeader(phase: .finished(.empty), total: 162)
}
