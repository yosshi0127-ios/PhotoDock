//
//  PhotoDetailView.swift
//  PhotoDock
//

import PhotosUI
import SwiftUI

/// 写真詳細（単発再診断）。開いた1枚を常に精密設定で診断する。
/// 入口は今は PhotosPicker だけだが、本筋はグリッドからの遷移（brief 76 / 79行）。
struct PhotoDetailView: View {
    /// 一覧から開いた場合の対象。nil なら PhotosPicker で選ばせる（暫定の入口）
    let assetID: String?

    @State private var state = PhotoDetailState()
    @State private var picked: PhotosPickerItem?

    init(assetID: String? = nil) {
        self.assetID = assetID
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = state.image {
                    PhotoWithFindings(image: image, findings: findings)
                }
                status
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if assetID == nil {
                PhotosPicker("写真を選ぶ", selection: $picked, matching: .images)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
        .task(id: picked) { await check(picked) }
        .task {
            guard let assetID else { return }
            await state.check(assetID: assetID)
        }
    }

    /// PhotosPicker の選択から画像データを取り出して State に渡す。
    /// 取り出しに失敗した nil も State に渡す（undecodable として表示される）
    private func check(_ item: PhotosPickerItem?) async {
        guard assetID == nil, let item else { return }
        await state.check(imageData: try? await item.loadTransferable(type: Data.self))
    }

    private var findings: [Finding] {
        if case let .checked(findings) = state.phase { findings } else { [] }
    }

    @ViewBuilder
    private var status: some View {
        switch state.phase {
        case .empty:
            ContentUnavailableView(
                "写真を選んでください",
                systemImage: "photo.on.rectangle.angled",
                description: Text("選んだ1枚を精密に診断します")
            )

        case .checking:
            ProgressView("この写真を確認しています")

        case let .checked(findings) where findings.isEmpty:
            Label("見られたらまずい情報は見つかりませんでした", systemImage: "checkmark.circle")

        case let .checked(findings):
            FindingListView(findings: findings)

        case .undecodable:
            ContentUnavailableView(
                "この写真を読み込めませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("別の写真を選んでください")
            )

        case .notAvailableLocally:
            ContentUnavailableView(
                "この写真は端末にありません",
                systemImage: "icloud.slash",
                description: Text("iCloud にのみ保存されているため診断できません")
            )
        }
    }
}

#Preview {
    PhotoDetailView()
}
