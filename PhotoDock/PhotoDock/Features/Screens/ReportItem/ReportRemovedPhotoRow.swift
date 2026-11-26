//
//  ReportRemovedPhotoRow.swift
//  PhotoDock
//

import SwiftUI

/// 非表示にした・削除した写真の1行。写真はもう読めないので、サムネイルの代わりに対処の記号を置く。
/// 画像は残していない（危険な写真を消したのに、縮小画像がアプリに残っては意味がない）
struct ReportRemovedPhotoRow: View {
    let photo: ReportRemovedPhoto
    /// 開いている項目。札の中で、この種類だけ強調する
    let openedKind: FindingKind

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: photo.action.symbol)
                .font(.title3)
                .foregroundStyle(Color.inkSecondary)
                .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
                .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(photo.takenAt?.reportDayText ?? "撮影日不明")
                    .font(.rowLabel)
                Text("\(photo.action.pastLabel) ・ \(photo.decidedAt.reportShortDayText)")
                    .font(.label)
                    .foregroundStyle(Color.themeAccent)
                FlowLayout {
                    ForEach(photo.kinds, id: \.self) { kind in
                        Text(kind.label)
                            .font(.label)
                            .foregroundStyle(kind == openedKind ? Color.ink : Color.inkSecondary)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let day = Date(timeIntervalSince1970: 1_763_600_000)
    VStack(spacing: 0) {
        ReportRemovedPhotoRow(
            photo: ReportRemovedPhoto(
                assetID: "a", action: .deleted, takenAt: day.addingTimeInterval(-86_400 * 40), decidedAt: day,
                kinds: [.cardNumber]
            ),
            openedKind: .cardNumber
        )
        ReportRemovedPhotoRow(
            photo: ReportRemovedPhoto(
                assetID: "b", action: .hidden, takenAt: nil, decidedAt: day, kinds: [.address, .phoneNumber]
            ),
            openedKind: .address
        )
    }
    .background(Color.surface)
}
