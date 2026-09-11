//
//  FlaggedPhotoCell.swift
//  PhotoDock
//

import SwiftUI

/// 所見のあった写真1枚。サムネイルと、最も高い重大度のバッジを出す。
struct FlaggedPhotoCell: View {
    let record: ScanRecord

    @State private var state = ThumbnailState()

    /// 画面の倍率から決める。セル幅は adaptive(minimum: 100) で最大 190pt 前後になるので、
    /// 固定の 240px だと 3× 端末（375〜570px 必要）でぼやける
    @Environment(\.displayScale) private var displayScale
    private var thumbnailPixels: Int { Int(200 * displayScale) }

    var body: some View {
        // 先に正方形の枠を作ってから中身を重ねる。
        // Image に直接 clipShape しても見た目が切れるだけでレイアウトサイズは縮まず、
        // scaledToFill した画像が隣のセルにはみ出す
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { thumbnail }
            .clipShape(.rect(cornerRadius: 8))
            // 白い写真だと隣のセルとの境が分からなくなる
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5) }
            .overlay(alignment: .topTrailing) { badge }
            .task { await state.load(assetID: record.assetID, maxPixelSize: thumbnailPixels) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = state.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            // 読み込み中と失敗を同じ見た目にする（グリッドがガタつかないよう枠は保つ）
            Rectangle()
                .fill(.quaternary)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let severity = record.findings.highestSeverity {
            Image(systemName: severity.icon)
                .foregroundStyle(severity.tint)
                .padding(6)
                .background(.regularMaterial, in: .circle)
                .padding(4)
        }
    }

    /// バッジは色と記号なので、読み上げでは種類と件数を言葉にする
    private var accessibilityLabel: String {
        let severity = record.findings.highestSeverity?.label ?? ""
        return "\(severity)、所見\(record.findings.count)件"
    }
}

#Preview {
    FlaggedPhotoCell(
        record: ScanRecord(
            assetID: "stub-0",
            modificationDate: nil,
            scannedAt: Date(timeIntervalSince1970: 1_757_000_000),
            quality: .quick,
            generation: "preview",
            outcome: .scanned([
                StoredFinding(
                    kind: .cardNumber,
                    severity: .danger,
                    region: Region(x: 0, y: 0, width: 1, height: 1)
                )
            ])
        )
    )
    .frame(width: 120, height: 120)
}
