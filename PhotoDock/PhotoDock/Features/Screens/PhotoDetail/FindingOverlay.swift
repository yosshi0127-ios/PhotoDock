//
//  FindingOverlay.swift
//  PhotoDock
//

import SwiftUI

/// 所見の検出領域を写真の上に重ねる枠。
/// Region は左上原点・0...1 正規化なので、Canvas がくれる size を掛けるだけで座標になる。
/// 前提: 重ねる相手の Image に .scaledToFit() が付いていること（枠 = 写真の実描画矩形）
struct FindingOverlay: View {
    let findings: [StoredFinding]

    var body: some View {
        Canvas { context, size in
            for finding in findings {
                let region = finding.region
                let rect = CGRect(
                    x: region.x * size.width,
                    y: region.y * size.height,
                    width: region.width * size.width,
                    height: region.height * size.height
                )

                context.stroke(
                    Path(rect),
                    with: .color(finding.severity.tint),
                    style: finding.severity.strokeStyle
                )
            }
        }
        // 位置は視覚情報。読み上げは所見リスト側が担う
        .accessibilityHidden(true)
    }
}

#Preview {
    Color.gray
        .frame(width: 300, height: 400)
        .overlay {
            FindingOverlay(findings: [
                StoredFinding(
                    kind: .cardNumber,
                    severity: .danger,
                    region: Region(x: 0.1, y: 0.2, width: 0.6, height: 0.08)
                ),
                StoredFinding(
                    kind: .address,
                    severity: .caution,
                    region: Region(x: 0.05, y: 0.5, width: 0.8, height: 0.06)
                )
            ])
        }
}
