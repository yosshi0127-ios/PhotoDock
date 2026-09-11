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
                    header
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

    /// 上に固定する部分。進捗（完了後は結果）と1行の要約だけに絞り、下のグリッドを圧迫しない
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state.phase {
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

    @ViewBuilder
    private var emptyState: some View {
        switch state.phase {
        case .finished:
            // 検出は原理的に不完全なので、ゼロ件でも「安全です」とは言わない
            Label("見られたらまずい情報は見つかりませんでした", systemImage: "checkmark.circle")
                .padding()
        default:
            Text("所見のある写真がここに増えていきます")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        }
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

    @ViewBuilder
    private func result(_ summary: ScanSummary) -> some View {
        if summary.flaggedPhotos == 0 {
            Label("見られたらまずい情報は見つかりませんでした", systemImage: "checkmark.circle")
        } else {
            Label("\(summary.flaggedPhotos.formatted()) 枚に所見があります", systemImage: "exclamationmark.circle")
        }
    }

    /// 危険・要注意・未診断を1行で。詳細な内訳（ScanCountsView）は完了後にグリッドの上へ
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
