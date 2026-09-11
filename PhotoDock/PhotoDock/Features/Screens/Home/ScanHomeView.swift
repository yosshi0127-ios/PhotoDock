//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI

/// 診断ホーム。第1段スキャンで対象を数え、全量診断への入口だけを出す。
/// 位置情報やスクショの内訳は数えてはいるが表示しない
/// （それ自体では行動に繋がらない。使うのは Phase 1.5 の地図ドリルダウン）。
/// 表示の中身は状態ごとの View に分けてあるので、ここは phase の振り分けだけを持つ。
struct ScanHomeView: View {
    @State private var state = ScanHomeState()

    /// 「iCloud の写真も診断する」。既定オフ（ユーザーの回線を勝手に使わない）。
    /// 表示の設定なので View が持つ（@AppStorage は @Observable の中では更新が伝わらない）
    @AppStorage("allowsCloudDownload") private var allowsCloudDownload = false

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
        case let .loaded(.scanned(access: access, inventory: inventory, assets: assets)):
            ScanStartView(
                inventory: inventory,
                assets: assets,
                access: access,
                allowsCloudDownload: $allowsCloudDownload
            )

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
