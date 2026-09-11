//
//  FullScanView.swift
//  PhotoDock
//

import SwiftUI

/// 全量スキャン（第2段）。開いた瞬間に走り出し、画面を離れると止まる。
/// 対象は診断ホームが第1段の結果から渡す。
struct FullScanView: View {
    let assets: [AssetMetadata]
    let quality: ScanQuality

    @State private var state = FullScanState()

    var body: some View {
        VStack(spacing: 32) {
            content
        }
        .padding()
        .navigationTitle("診断")
        .navigationBarTitleDisplayMode(.inline)
        // .task は一覧から戻るたびに走るので、自動開始は State 側で一度きりに絞る
        .task { await state.startIfNeeded(assets: assets, quality: quality) }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle:
            ProgressView()

        case let .scanning(summary):
            progress(summary)
            ScanCountsView(summary: summary)

        case let .finished(summary):
            result(summary)
            ScanCountsView(summary: summary)
            elapsed

            if !state.flagged.isEmpty {
                NavigationLink("写真を確認する") {
                    FlaggedPhotoGridView(records: state.flagged)
                }
                .buttonStyle(.borderedProminent)
            }

            // action: に関数参照を直接渡すと Preview のコード変換だけが壊れる
            // （ambiguous use of '__designTimeSelection'）。通常ビルドは通るので気づきにくい
            Button("もう一度診断") { rescan() }
                .buttonStyle(.bordered)
        }
    }

    private var elapsed: some View {
        LabeledContent("所要時間") {
            Text("\(state.elapsedSeconds.formatted(.number.precision(.fractionLength(1)))) 秒")
                .monospacedDigit()
        }
    }

    private func rescan() {
        Task { await state.restart(assets: assets, quality: quality) }
    }

    private func progress(_ summary: ScanSummary) -> some View {
        // total が 0 でも割り算が壊れないように下限を 1 にする
        ProgressView(value: Double(summary.completed), total: Double(max(1, state.total))) {
            Text("写真を診断しています")
        } currentValueLabel: {
            Text("\(summary.completed.formatted()) / \(state.total.formatted()) 枚")
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
}

#Preview {
    NavigationStack {
        FullScanView(
            assets: (0..<40).map {
                AssetMetadata(
                    id: "stub-\($0)",
                    creationDate: nil,
                    modificationDate: nil,
                    coordinate: nil,
                    isScreenshot: false
                )
            },
            quality: .precise
        )
    }
}
