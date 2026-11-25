//
//  FlaggedPhotosOfKindView.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の行を押した先。その種類が写っている写真だけを、今ある格子で出す
/// （項目ごとの一覧画面を作るまでのつなぎ）。ホームと診断中の画面で同じものを使う
struct FlaggedPhotosOfKindView: View {
    let kind: FindingKind
    /// 所見のある写真の記録。この中から `kind` が写っているものだけを出す
    let records: [ScanRecord]

    var body: some View {
        ScrollView {
            FlaggedPhotoGridView(records: records.filter { record in
                record.findings.contains { $0.kind == kind }
            })
            .padding(Spacing.xxs)
        }
        .background(Color.ground)
        .navigationTitle(kind.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
