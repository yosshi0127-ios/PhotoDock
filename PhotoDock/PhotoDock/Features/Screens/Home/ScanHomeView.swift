//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI

/// 診断ホーム。第1段スキャンで対象を数え、全量診断への入口だけを出す。
/// 位置情報やスクショの内訳は数えてはいるが表示しない
/// （それ自体では行動に繋がらない。使うのは Phase 1.5 の地図ドリルダウン）。
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
        case let .loaded(.scanned(access: access, inventory: inventory, assets: assets)):
            VStack(spacing: 16) {
                if assets.isEmpty {
                    ContentUnavailableView(
                        "診断できる写真がありません",
                        systemImage: "photo.on.rectangle.angled"
                    )
                } else {
                    // 枚数はボタンに載せる。押した先で何枚処理されるかが分かる。
                    // 品質は精密のみ（実機でクイックの 1.63 倍で済み、一覧と詳細の食い違いが構造的に消える）
                    NavigationLink("\(inventory.total.formatted())枚を診断") {
                        FullScanView(assets: assets, quality: .precise)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if access == .limited {
                    limitedNotice
                }
            }

        case let .loaded(.unavailable(access: access)):
            ScanUnavailableView(access: access)
        }
    }

    /// 全量を見られていないことは伝える（見えていない分を「無かった」と誤解させない）
    private var limitedNotice: some View {
        Text("選択された写真だけを診断します。すべてを診断するには、写真へのフルアクセスを許可してください。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

// toolbar と navigationTitle は NavigationStack の中でしか描かれないので Preview でも包む
#Preview {
    NavigationStack {
        ScanHomeView()
    }
}
