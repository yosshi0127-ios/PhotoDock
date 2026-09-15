//
//  FullScanView.swift
//  PhotoDock
//

import SwiftUI

/// 全量スキャン（第2段）。開いた瞬間に走り出し、画面を閉じると止まる。
/// 進捗を上に固定し、所見のあった写真は診断中からその下に増えていく
/// （数十分かかる処理なので、終わるまで結果が見えないのは長すぎる）。
/// 写真詳細を開いている間も診断は続く。アプリを離れたときの継続は OS への申告が通ったときだけ
/// （背景で GPU を使う entitlement が要る。詳細は brief「検証済みの事実」）。
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
            if let rerunTitle {
                ToolbarItem(placement: .topBarTrailing) {
                    // action: に関数参照を直接渡すと Preview のコード変換だけが壊れる
                    Button(rerunTitle) { rerun() }
                }
            }
        }
        // .task ではなく onAppear で同期に始める。.task は子画面を push しただけでキャンセルされるうえ、
        // 終わりまで await すると State を掴み続けて画面を閉じても捨てられない。
        // 詳細から戻るたびに走るので、自動開始は State 側で一度きりに絞る
        .onAppear { state.startIfNeeded(assets: assets, quality: quality, allowsDownload: allowsDownload) }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case let .finished(summary), let .interrupted(summary):
            ScanCountsView(summary: summary)
                .padding(.horizontal)
            elapsed
                .padding(.horizontal)
        case .idle, .scanning:
            EmptyView()
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
        case .interrupted:
            Text("ここまでに所見のある写真はありません")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        case .idle, .scanning:
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

    /// 完了後と中断後にだけ出す。中断後は「続き」と言う（記録があるので実際に続きから走る）
    private var rerunTitle: String? {
        switch state.phase {
        case .finished: "もう一度診断"
        case .interrupted: "続きを診断"
        case .idle, .scanning: nil
        }
    }

    private func rerun() {
        state.restart(assets: assets, quality: quality, allowsDownload: allowsDownload)
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
