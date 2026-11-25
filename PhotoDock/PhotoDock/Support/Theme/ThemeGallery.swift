//
//  ThemeGallery.swift
//  PhotoDock
//

import SwiftUI

/// テーマの見本。配色と文字の大きさを Preview で確かめるためだけの View（画面からは使わない）
struct ThemeGallery: View {
    private let swatches: [(name: String, color: Color)] = [
        ("ground", .ground), ("surface", .surface), ("surfaceMuted", .surfaceMuted),
        ("ink", .ink), ("inkSecondary", .inkSecondary),
        ("themeAccent", .themeAccent), ("accentSurface", .accentSurface),
        ("danger", .danger), ("dangerSurface", .dangerSurface),
        ("caution", .caution), ("cautionSurface", .cautionSurface),
        ("hairline", .hairline)
    ]

    var body: some View {
        ScrollView {
            samples
        }
        .background(Color.ground)
    }

    /// 見本の中身。スクロール領域の外でも描けるように分けてある
    var samples: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("診断結果票").font(.screenTitle)
            Text("要確認 9 枚").font(.verdict).foregroundStyle(Color.caution)
            Text("2026年11月20日 診断 ・ 端末の写真 853 枚").font(.note).foregroundStyle(Color.inkSecondary)

            VStack(spacing: 0) {
                ForEach(swatches, id: \.name) { swatch in
                    HStack(spacing: Spacing.s) {
                        RoundedRectangle(cornerRadius: Metrics.tagRadius)
                            .fill(swatch.color)
                            .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
                            .frame(width: 44, height: 28)
                        Text(swatch.name).font(.rowLabel)
                        Spacer()
                    }
                    .frame(minHeight: Metrics.rowMinHeight)
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))

            Text("新しい写真を診断する")
                .font(.action)
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity, minHeight: Metrics.actionMinHeight)
                .background(Color.themeAccent, in: .rect(cornerRadius: Metrics.cardRadius))

            Text("危険の 3 枚から確認する")
                .font(.action)
                .foregroundStyle(Color.onDanger)
                .frame(maxWidth: .infinity, minHeight: Metrics.actionMinHeight)
                .background(Color.danger, in: .rect(cornerRadius: Metrics.cardRadius))
        }
        .padding(Spacing.l)
        .foregroundStyle(Color.ink)
        .background(Color.ground)
    }
}

#Preview("ライト") {
    ThemeGallery()
        .preferredColorScheme(.light)
}

#Preview("ダーク") {
    ThemeGallery()
        .preferredColorScheme(.dark)
}
