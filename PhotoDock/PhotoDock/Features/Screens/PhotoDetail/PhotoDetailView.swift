//
//  PhotoDetailView.swift
//  PhotoDock
//

import SwiftUI

/// 写真詳細。結果票の項目から開く。記録を表示するだけで、診断はしない（一覧と同じものを見せる）
struct PhotoDetailView: View {
    let record: ScanRecord

    @State private var state = PhotoDetailState()

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
        .task { await state.show(record: record) }
    }

    private var findings: [StoredFinding] {
        if case let .checked(findings) = state.phase { findings } else { [] }
    }

    @ViewBuilder
    private var status: some View {
        switch state.phase {
        case .empty, .checking:
            ProgressView("写真を確認しています")

        case let .checked(findings):
            FindingListView(findings: findings)
        }
    }
}

#Preview {
    NavigationStack {
        PhotoDetailView(record: InMemoryScanRecordRepository.previewSeed[0])
    }
}
