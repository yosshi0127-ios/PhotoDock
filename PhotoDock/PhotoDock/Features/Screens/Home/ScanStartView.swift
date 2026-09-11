//
//  ScanStartView.swift
//  PhotoDock
//

import SwiftUI

/// 診断開始のカード。第1段の結果（枚数・権限）と「iCloud の写真も診断する」の設定を受け、
/// 全量診断へ送る。品質は精密のみ（実機でクイックの 1.63 倍で済み、一覧と詳細の食い違いが構造的に消える）。
struct ScanStartView: View {
    let inventory: LibraryInventory
    let assets: [AssetMetadata]
    let access: PhotoLibraryAccess
    @Binding var allowsCloudDownload: Bool

    var body: some View {
        VStack(spacing: 16) {
            if assets.isEmpty {
                ContentUnavailableView(
                    "診断できる写真がありません",
                    systemImage: "photo.on.rectangle.angled"
                )
            } else {
                // 枚数はボタンに載せる。押した先で何枚処理されるかが分かる
                NavigationLink("\(inventory.total.formatted())枚を診断") {
                    FullScanView(assets: assets, quality: .precise, allowsDownload: allowsCloudDownload)
                }
                .buttonStyle(.borderedProminent)

                // iCloud 最適化オンの端末では 80% が端末に無い（実測）。既定オフで、Wi-Fi のときだけ取る
                Toggle("iCloud の写真も診断する", isOn: $allowsCloudDownload)
                    .font(.subheadline)
                Text("端末に無い写真を Wi-Fi 接続時に取り寄せます（1枚あたり約300KB）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if access == .limited {
                limitedNotice
            }
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

#Preview("フルアクセス") {
    @Previewable @State var allows = false
    NavigationStack {
        ScanStartView(
            inventory: LibraryInventory(total: 1_240, withLocation: 310, screenshots: 486),
            assets: [AssetMetadata(id: "stub-0", creationDate: nil, modificationDate: nil, coordinate: nil, isScreenshot: false)],
            access: .full,
            allowsCloudDownload: $allows
        )
        .padding()
    }
}

#Preview("一部のみ許可") {
    @Previewable @State var allows = true
    NavigationStack {
        ScanStartView(
            inventory: LibraryInventory(total: 12, withLocation: 3, screenshots: 4),
            assets: [AssetMetadata(id: "stub-0", creationDate: nil, modificationDate: nil, coordinate: nil, isScreenshot: false)],
            access: .limited,
            allowsCloudDownload: $allows
        )
        .padding()
    }
}
