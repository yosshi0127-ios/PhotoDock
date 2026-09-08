//
//  ScanUnavailableView.swift
//  PhotoDock
//

import SwiftUI

/// 診断できなかったときの案内。`denied` と `restricted` で内容が正反対になる
/// （前者は設定アプリで変えられる／後者はユーザーには変えられない）。
///
/// 写真の許可はアプリの生涯で一度しか問えないため、ここが復帰の唯一の導線になる。
/// 手組みのレイアウトをやめて `ContentUnavailableView` に寄せ、
/// アイコン・余白・文字階層・VoiceOver の扱いをシステムに任せる。
struct ScanUnavailableView: View {
    let access: PhotoLibraryAccess

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch access {
        case .denied:
            ContentUnavailableView {
                Label("写真へのアクセスが許可されていません", systemImage: "lock")
            } description: {
                Text("設定アプリで許可すると、カメラロールの診断ができます。")
            } actions: {
                Button("設定を開く", action: openSettings)
            }

        case .restricted:
            ContentUnavailableView {
                Label("写真へのアクセスが制限されています", systemImage: "lock.slash")
            } description: {
                Text("機能制限により、このデバイスでは許可できません。")
            }

        case .notDetermined, .full, .limited:
            // ここには来ない想定。default を書かないので、ケース追加時にコンパイラが指摘する
            ContentUnavailableView {
                Label("写真を読み込めませんでした", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview("拒否された") {
    ScanUnavailableView(access: .denied)
}

#Preview("機能制限") {
    ScanUnavailableView(access: .restricted)
}

#Preview("想定外") {
    ScanUnavailableView(access: .notDetermined)
}
