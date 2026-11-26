//
//  ReportItemView.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の項目（種類）を開いた先。その種類が写っている写真を、1枚1行で並べる。
/// ホームと診断中の画面で同じものを使う（診断中は、見つかるたびに行が増える）
struct ReportItemView: View {
    let kind: FindingKind
    /// 結果票の、この項目の行（判定と枚数）。まだ結果票が無ければ nil
    let item: ScanReport.Item?
    /// 並び順は Policy が決めてある（危険が先、その中で新しい写真が先）
    let photos: [ReportItemPhoto]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                list
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("診断結果票")
                .font(.label)
                .foregroundStyle(Color.inkSecondary)
            Text(kind.label)
                .font(.screenTitle)
            if let item {
                Text("\(item.verdict.label) \(item.photoCount.formatted()) 枚")
                    .font(.sectionTitle)
                    .foregroundStyle(item.verdict.tint)
            }
            Text(kind.itemNote)
                .font(.note)
                .foregroundStyle(Color.inkSecondary)
                .padding(.top, Spacing.xxs)
        }
    }

    @ViewBuilder
    private var list: some View {
        if photos.isEmpty {
            Text("この項目の写真はありません")
                .font(.note)
                .foregroundStyle(Color.inkSecondary)
        } else {
            // 数十〜数百行になりうるので、画面に出た行だけを作る（サムネイルの読み込みも行ごと）
            LazyVStack(spacing: 0) {
                ForEach(photos) { photo in
                    if photo.id != photos.first?.id {
                        Divider().overlay(Color.hairline)
                    }
                    NavigationLink {
                        PhotoDetailView(photo: photo)
                    } label: {
                        ReportItemPhotoRow(photo: photo, openedKind: kind)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
            .clipShape(.rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
            }
        }
    }
}

#Preview("住所・要確認") {
    NavigationStack {
        ReportItemView(
            kind: .address,
            item: ScanReport.Item(kind: .address, verdict: .caution, photoCount: 3),
            photos: ReportItemPhoto.previewAddress
        )
    }
}

#Preview("認証情報・危険あり") {
    NavigationStack {
        ReportItemView(
            kind: .credential,
            item: ScanReport.Item(kind: .credential, verdict: .danger, photoCount: 2),
            photos: ReportItemPhoto.previewCredential
        )
    }
}
