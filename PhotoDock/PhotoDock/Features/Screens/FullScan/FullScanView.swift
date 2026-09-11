//
//  FullScanView.swift
//  PhotoDock
//

import SwiftUI

/// 全量スキャン（第2段）。開いた瞬間に走り出し、画面を離れると止まる。
/// 進捗を上に固定し、所見のあった写真は診断中からその下に増えていく
/// （数十分かかる処理なので、終わるまで結果が見えないのは長すぎる）。
struct FullScanView: View {
    let assets: [AssetMetadata]
    let quality: ScanQuality
    /// 「iCloud の写真も診断する」の設定値。回線の判定は UseCase が行う
    let allowsDownload: Bool

    @State private var state = FullScanState()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                Section {
                    content
                } header: {
                    FullScanHeader(phase: state.phase, total: state.total)
                }
            }
        }
        .navigationTitle("診断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .finished = state.phase {
                ToolbarItem(placement: .topBarTrailing) {
                    // action: に関数参照を直接渡すと Preview のコード変換だけが壊れる
                    Button("もう一度診断") { rescan() }
                }
            }
        }
        // .task は詳細から戻るたびに走るので、自動開始は State 側で一度きりに絞る
        .task { await state.startIfNeeded(assets: assets, quality: quality, allowsDownload: allowsDownload) }
    }

    @ViewBuilder
    private var content: some View {
        if case let .finished(summary) = state.phase {
            ScanCountsView(summary: summary)
                .padding(.horizontal)
            elapsed
                .padding(.horizontal)
        }

        if state.flagged.isEmpty {
            emptyState
        } else {
            FlaggedPhotoGridView(records: state.flagged)
                .padding(.horizontal, 4)
        }
    }

    /// 結論（見つかった／見つからなかった）はヘッダが言うので、ここでは繰り返さない
    @ViewBuilder
    private var emptyState: some View {
        switch state.phase {
        case .finished:
            Text("所見のある写真はありません")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        default:
            Text("所見のある写真がここに増えていきます")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private var elapsed: some View {
        LabeledContent("所要時間") {
            Text("\(state.elapsedSeconds.formatted(.number.precision(.fractionLength(1)))) 秒")
                .monospacedDigit()
        }
    }

    private func rescan() {
        Task { await state.restart(assets: assets, quality: quality, allowsDownload: allowsDownload) }
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
            quality: .precise,
            allowsDownload: false
        )
    }
}
