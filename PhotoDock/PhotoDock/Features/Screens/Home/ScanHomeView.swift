//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI

struct ScanHomeView: View {
    @State private var state = ScanHomeState()

    /// 表の行を押して開いている項目
    @State private var selectedKind: FindingKind?

    var body: some View {
        @Bindable var state = state

        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $state.isScanPresented) {
                FullScanView(
                    assets: assets,
                    quality: state.quality,
                    allowsDownload: state.scanAllowsDownload,
                    expectedToDiagnose: state.expectedToDiagnose
                )
            }
            .navigationDestination(item: $selectedKind) { kind in
                ReportItemView(kind: kind, item: state.item(of: kind), photos: state.photos(of: kind)) {
                    // 写真詳細で対応を付け外ししたら、結果票と一覧を読み直す
                    await state.load()
                }
            }
            .sheet(isPresented: $state.isCloudConfirmPresented, onDismiss: { cloudConfirmDidDismiss() }, content: {
                if let estimate = state.cloudEstimate {
                    CloudScanConfirmView(
                        estimate: estimate,
                        isOffWiFi: state.isOffWiFi,
                        onStart: { confirmCloudScan() },
                        onCancel: { cancelCloudScan() }
                    )
                }
            })
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
                    onScan: { startScan() },
                    onCloudScan: { askCloudScan() },
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

    private func askCloudScan() {
        state.askCloudScan()
    }

    private func confirmCloudScan() {
        Task { await state.confirmCloudScan() }
    }

    private func cancelCloudScan() {
        state.isCloudConfirmPresented = false
    }

    private func cloudConfirmDidDismiss() {
        state.cloudConfirmDidDismiss()
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
}

#Preview {
    NavigationStack {
        ScanHomeView()
    }
}
