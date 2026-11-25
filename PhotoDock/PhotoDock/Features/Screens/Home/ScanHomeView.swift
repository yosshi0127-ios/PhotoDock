//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI

struct ScanHomeView: View {
    @State private var state = ScanHomeState()

    /// 表の行を押して開いている項目
    @State private var selectedKind: FindingKind?

    /// 「iCloud の写真も診断する」。既定オフ（ユーザーの回線を勝手に使わない）。
    /// 表示の設定なので View が持つ（@AppStorage は @Observable の中では更新が伝わらない）
    @AppStorage("allowsCloudDownload") private var allowsCloudDownload = false

    var body: some View {
        @Bindable var state = state

        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("1枚チェック") { PhotoDetailView() }
                }
            }
            .navigationDestination(isPresented: $state.isScanPresented) {
                FullScanView(assets: assets, quality: state.quality, allowsDownload: allowsCloudDownload)
            }
            .navigationDestination(item: $selectedKind) { kind in
                flaggedPhotos(of: kind)
            }
            // 表示されるたびに読み直す（診断から戻ったときに結果票を更新するため）。
            // 読むだけなので、途中で打ち切られても前の表示が残るだけ
            .task { await state.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            ProgressView("カメラロールを確認しています")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ground)

        case .loaded(.needsPermission):
            WelcomeView(mode: .needsPermission) { allowAccess() }

        case let .loaded(.unavailable(access)):
            ScanUnavailableView(access: access)

        case let .loaded(.ready(content)):
            if let report = content.report {
                ReportHomeView(
                    content: content,
                    report: report,
                    allowsCloudDownload: $allowsCloudDownload,
                    onScan: { startScan() },
                    onSelect: { select($0) }
                )
            } else {
                WelcomeView(mode: .firstScan(photoCount: content.assets.count)) { startScan() }
            }
        }
    }

    // MARK: - 操作（レイアウトと混ぜないよう、body の外に置く）

    /// 初回の案内のボタン。ここで初めてアクセスの確認が出る
    private func allowAccess() {
        Task { await state.allowAccessAndStartScan() }
    }

    private func startScan() {
        state.startScan()
    }

    private func select(_ kind: FindingKind) {
        selectedKind = kind
    }

    /// 診断の対象。診断できる状態でしか診断画面は出ない
    private var assets: [AssetMetadata] {
        if case let .loaded(.ready(content)) = state.phase { content.assets } else { [] }
    }

    /// 項目を押した先。その種類が写っている写真だけを、今ある格子で出す
    /// （項目ごとの一覧画面を作るまでのつなぎ）
    private func flaggedPhotos(of kind: FindingKind) -> some View {
        let records: [ScanRecord] = if case let .loaded(.ready(content)) = state.phase {
            content.flagged.filter { record in record.findings.contains { $0.kind == kind } }
        } else {
            []
        }

        return ScrollView {
            FlaggedPhotoGridView(records: records)
                .padding(Spacing.xxs)
        }
        .background(Color.ground)
        .navigationTitle(kind.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ScanHomeView()
    }
}
