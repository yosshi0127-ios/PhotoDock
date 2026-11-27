//
//  ReportItemPhotoRow.swift
//  PhotoDock
//

import SwiftUI

/// 項目の一覧の1行。サムネイル、撮った日、その写真に写っている種類の札を並べる
struct ReportItemPhotoRow: View {
    let photo: ReportItemPhoto
    /// 開いている項目。札の中で、この種類だけ強調する
    let openedKind: FindingKind

    @State private var thumbnail = ThumbnailState()

    /// 画面の倍率から決める（固定の大きさだと、3× の端末でぼやける）
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            image

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(photo.takenAt?.reportDayText ?? "撮影日不明")
                        .font(.rowLabel)
                    if photo.isHandled {
                        Text("問題なし")
                            .font(.label)
                            .foregroundStyle(Color.themeAccent)
                    } else if photo.verdict == .danger {
                        Text(photo.verdict.label)
                            .font(.label)
                            .foregroundStyle(Color.danger)
                    }
                }
                FlowLayout {
                    ForEach(photo.kinds, id: \.self) { kind in
                        tag(kind)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .frame(height: Metrics.thumbnailSize)
                .accessibilityHidden(true)
        }
        .padding(Spacing.s)
        .background(photo.verdict == .danger && !photo.isHandled ? Color.dangerSurface : Color.clear, in: .rect)
        .contentShape(.rect)
        .task { await thumbnail.load(assetID: photo.id, maxPixelSize: Int(Metrics.thumbnailSize * displayScale)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.accessibilityText)
    }

    private var image: some View {
        // 先に正方形の枠を作ってから中身を重ねる（画像に直接 clipShape しても、レイアウトの大きさは縮まない）
        Color.surfaceMuted
            .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
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
                    .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
            }
            .accessibilityHidden(true)
    }

    private func tag(_ kind: FindingKind) -> some View {
        Text(kind.label)
            .font(.label)
            .foregroundStyle(kind == openedKind ? Color.ink : Color.inkSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
    }

}

extension ReportItemPhoto {
    /// 読み上げ用の説明。1行ずつの表示でも、格子の表示でも、同じことを伝える
    var accessibilityText: String {
        let day = takenAt?.reportDayText ?? "撮影日不明"
        let kindNames = kinds.map(\.label).joined(separator: "、")
        let state = isHandled ? "問題なしにした写真" : verdict.label
        return "\(day)、\(state)、\(kindNames)"
    }
}

#Preview {
    VStack(spacing: 0) {
        ReportItemPhotoRow(photo: ReportItemPhoto.previewCredential[0], openedKind: .credential)
        ReportItemPhotoRow(photo: ReportItemPhoto.previewAddress[0], openedKind: .address)
    }
    .background(Color.surface)
}
