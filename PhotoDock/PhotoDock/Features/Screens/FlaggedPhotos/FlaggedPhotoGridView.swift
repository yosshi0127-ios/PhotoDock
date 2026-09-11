//
//  FlaggedPhotoGridView.swift
//  PhotoDock
//

import SwiftUI

/// 所見のあった写真のグリッド。タップで写真詳細へ。
/// スクロールは持たない — 全量スキャンの画面に埋め込まれ、診断中に増えていく前提。
/// 入力は保存用の記録（本文なし）。バッジに要るのは種類と severity だけで、
/// 本文は詳細を開いたときに初めて必要になる。
/// LazyVGrid なので、サムネイルの読み込みは画面に出たセルだけで走る。
struct FlaggedPhotoGridView: View {
    let records: [ScanRecord]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(records, id: \.assetID) { record in
                NavigationLink {
                    PhotoDetailView(record: record)
                } label: {
                    FlaggedPhotoCell(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            FlaggedPhotoGridView(records: (0..<12).map { index in
                ScanRecord(
                    assetID: "stub-\(index * 7)",
                    modificationDate: nil,
                    scannedAt: Date(timeIntervalSince1970: 1_757_000_000),
                    quality: .precise,
                    generation: "preview",
                    outcome: .scanned([
                        StoredFinding(
                            kind: index.isMultiple(of: 3) ? .cardNumber : .address,
                            severity: index.isMultiple(of: 3) ? .danger : .caution,
                            region: Region(x: 0, y: 0, width: 1, height: 1)
                        )
                    ])
                )
            })
            .padding(4)
        }
    }
}
