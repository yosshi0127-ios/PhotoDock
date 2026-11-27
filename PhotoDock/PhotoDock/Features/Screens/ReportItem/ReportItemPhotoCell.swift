//
//  ReportItemPhotoCell.swift
//  PhotoDock
//

import SwiftUI

/// 項目の一覧を格子で出すときの1枚。写真だけを正方形で出し、判定は隅の印で示す。
/// 枚数が多い項目（顔の写り込みなど）で、スクロールの量を減らすために使う。
/// 撮った日と、ほかに写っている種類は出さない（知りたいときは、1行ずつの表示に切り替える）
struct ReportItemPhotoCell: View {
    let photo: ReportItemPhoto

    @State private var thumbnail = ThumbnailState()

    /// 画面の倍率から決める（固定の大きさだと、3× の端末でぼやける）
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // 先に正方形の枠を作ってから中身を重ねる（画像に直接 clipShape しても、レイアウトの大きさは縮まない）
        Color.surfaceMuted
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = thumbnail.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(.rect(cornerRadius: Metrics.tagRadius))
            // 白い写真だと、地との境が分からなくなる
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.tagRadius)
                    .stroke(isDanger ? Color.danger : Color.hairline, lineWidth: isDanger ? 2 : Metrics.hairlineWidth)
            }
            .overlay(alignment: .topLeading) { badge }
            .contentShape(.rect)
            .task { await thumbnail.load(assetID: photo.id, maxPixelSize: Int(Metrics.gridCellSize * displayScale)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photo.accessibilityText)
    }

    private var isDanger: Bool { photo.verdict == .danger && !photo.isHandled }

    /// 色だけに頼らず、記号でも分かるようにする
    @ViewBuilder
    private var badge: some View {
        if photo.isHandled {
            mark("checkmark", color: .themeAccent)
        } else if isDanger {
            mark("exclamationmark", color: .danger)
        }
    }

    private func mark(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color, in: .circle)
            .padding(Spacing.xxs)
            .accessibilityHidden(true)
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 3), spacing: Spacing.xxs) {
        ForEach(ReportItemPhoto.previewCredential + ReportItemPhoto.previewAddress) { photo in
            ReportItemPhotoCell(photo: photo)
        }
    }
    .padding()
    .background(Color.ground)
}
