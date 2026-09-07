//
//  ScanHomeView.swift
//  PhotoDock
//

import SwiftUI
import UIKit

/// 診断ホーム。第1段スキャン（台帳の集計）の結果を出す。
struct ScanHomeView: View {
    @State private var state = ScanHomeState()
    @Environment(\.openURL) private var openURL

    var body: some View {
        content
            .padding()
            .task { await state.startScan() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle, .scanning:
            ProgressView("カメラロールを確認しています")

        case let .loaded(.scanned(access, inventory)):
            summary(inventory, access: access)

        case let .loaded(.unavailable(access)):
            unavailable(access)
        }
    }

    private func summary(_ inventory: LibraryInventory, access: PhotoLibraryAccess) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(inventory.total.formatted())
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("枚の写真を確認しました")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                countRow("位置情報付き", count: inventory.withLocation)
                countRow("スクリーンショット", count: inventory.screenshots)
            }

            if access == .limited {
                Text("選択された写真だけを診断しています。すべてを診断するには、写真へのフルアクセスを許可してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func countRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(count.formatted())
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func unavailable(_ access: PhotoLibraryAccess) -> some View {
        VStack(spacing: 16) {
            switch access {
            case .denied:
                Text("写真へのアクセスが許可されていません")
                Text("設定アプリで許可すると、カメラロールの診断ができます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }

            case .restricted:
                Text("写真へのアクセスが制限されています")
                Text("機能制限により、このデバイスでは許可できません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .notDetermined, .full, .limited:
                Text("写真を読み込めませんでした")
            }
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    ScanHomeView()
}
