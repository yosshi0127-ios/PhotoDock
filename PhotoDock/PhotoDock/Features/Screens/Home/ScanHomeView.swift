//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI

/// 診断ホーム。第1段スキャン（台帳の集計）の結果を出す。
/// 表示の中身は状態ごとの View に分けてあるので、ここは phase の振り分けだけを持つ。
struct ScanHomeView: View {
    @State private var state = ScanHomeState()

    var body: some View {
        content
            .padding()
            .navigationTitle("写真ドック")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("1枚チェック") { PhotoDetailView() }
                }
            }
            .task { await state.startScan() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle, .scanning:
            ProgressView("カメラロールを確認しています")

        // ラベルを省くと Preview のコード変換だけが壊れる（通常ビルドは通る）
        case let .loaded(.scanned(access: access, inventory: inventory)):
            ScanSummaryView(inventory: inventory, access: access)

        case let .loaded(.unavailable(access: access)):
            ScanUnavailableView(access: access)
        }
    }
}

// toolbar と navigationTitle は NavigationStack の中でしか描かれないので Preview でも包む
#Preview {
    NavigationStack {
        ScanHomeView()
    }
}
