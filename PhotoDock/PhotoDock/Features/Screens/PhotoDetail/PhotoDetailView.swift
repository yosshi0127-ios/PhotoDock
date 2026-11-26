//
//  PhotoDetailView.swift
//  PhotoDock
//

import SwiftUI

/// 写真詳細。項目の一覧から開く。記録を表示するだけで、診断はしない（一覧と同じものを見せる）。
/// 写真の上に所見の場所を枠で示し、下に種類ごとの判定を並べる
struct PhotoDetailView: View {
    let photo: ReportItemPhoto

    @State private var state = PhotoDetailState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                picture
                PhotoFindingTable(findings: state.findings)
                sharingNote
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await state.show(record: photo.record) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("写真の所見")
                .font(.label)
                .foregroundStyle(Color.inkSecondary)
            Text(photo.takenAt?.reportDayText ?? "撮影日不明")
                .font(.screenTitle)
        }
    }

    @ViewBuilder
    private var picture: some View {
        if let image = state.image {
            PhotoWithFindings(image: image, findings: photo.record.findings)
                .clipShape(.rect(cornerRadius: Metrics.tagRadius))
                // 白い写真だと、地との境が分からなくなる
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.tagRadius)
                        .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
                }
                .frame(maxWidth: .infinity)
        } else {
            // 読み込み中も、読み込めなかったときも、同じ大きさの枠を置く（下の表が動かないように）
            Group {
                if state.isLoadingImage {
                    ProgressView("写真を読み込んでいます")
                } else {
                    Text("写真を表示できませんでした")
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .font(.note)
            .frame(maxWidth: .infinity)
            .aspectRatio(4 / 3, contentMode: .fit)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
        }
    }

    /// 経路ごとの札は出さない。いま見つけるのは写真に写っているものだけで、どの方法でも結果が同じため
    private var sharingNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("この写真を渡すと")
                .font(.sectionTitle)
            Text(photo.kinds.sharingNote)
                .font(.note)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.cardRadius))
        .accessibilityElement(children: .combine)
    }
}

#Preview("住所・電話番号・郵便番号") {
    NavigationStack {
        PhotoDetailView(photo: ReportItemPhoto.previewAddress[0])
    }
}

#Preview("撮影日不明") {
    NavigationStack {
        PhotoDetailView(photo: ReportItemPhoto.previewAddress[2])
    }
}
