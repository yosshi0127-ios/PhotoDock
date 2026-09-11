//
//  PhotoDetailView.swift
//  PhotoDock
//

import PhotosUI
import SwiftUI

/// 写真詳細。一覧から開いたときは記録を表示するだけで、診断はしない（一覧と同じものを見せる）。
/// PhotosPicker で1枚選ぶ入口（brief 79行「これから渡す1枚」）だけは記録が無いので精密で診断する。
struct PhotoDetailView: View {
    /// 一覧から開いた場合の記録。nil なら PhotosPicker で選ばせる
    let record: ScanRecord?

    @State private var state = PhotoDetailState()
    @State private var picked: PhotosPickerItem?

    init(record: ScanRecord? = nil) {
        self.record = record
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
            if record == nil {
                PhotosPicker("写真を選ぶ", selection: $picked, matching: .images)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
        .task(id: picked) { await check(picked) }
        .task {
            guard let record else { return }
            await state.show(record: record)
        }
    }

    /// PhotosPicker の選択から画像データを取り出して State に渡す。
    /// 取り出しに失敗した nil も State に渡す（undecodable として表示される）
    private func check(_ item: PhotosPickerItem?) async {
        guard record == nil, let item else { return }
        await state.check(imageData: try? await item.loadTransferable(type: Data.self))
    }

    private var findings: [StoredFinding] {
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
            ProgressView("写真を確認しています")

        case let .checked(findings) where findings.isEmpty:
            // 一覧から開いた写真は必ず所見があるので、ここに来るのは PhotosPicker 経路だけ
            Label("見られたらまずい情報は見つかりませんでした", systemImage: "checkmark.circle")

        case let .checked(findings):
            FindingListView(findings: findings)

        case .undecodable:
            ContentUnavailableView(
                "この写真を読み込めませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("別の写真を選んでください")
            )
        }
    }
}

#Preview("PhotosPicker で選ぶ") {
    PhotoDetailView()
}

#Preview("記録から開く") {
    NavigationStack {
        PhotoDetailView(record: InMemoryScanRecordRepository.previewSeed[0])
    }
}
