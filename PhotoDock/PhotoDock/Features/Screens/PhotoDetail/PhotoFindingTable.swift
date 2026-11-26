//
//  PhotoFindingTable.swift
//  PhotoDock
//

import SwiftUI

/// 写真詳細の所見の表。種類ごとに1行で、判定の言葉は結果票と同じ（危険・要確認・参考）
struct PhotoFindingTable: View {
    let findings: [ReportPhotoFinding]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(findings) { finding in
                if finding.id != findings.first?.id {
                    Divider().overlay(Color.hairline)
                }
                row(finding)
            }
        }
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .clipShape(.rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
    }

    private func row(_ finding: ReportPhotoFinding) -> some View {
        HStack(spacing: Spacing.s) {
            Text(finding.kind.label)
                .font(finding.verdict == .danger ? .rowValue : .rowLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            // 1か所のときは言わない（ほとんどの写真がそうなので、毎行に出ると邪魔になる）
            if finding.placeCount > 1 {
                Text("\(finding.placeCount.formatted()) か所")
                    .font(.note)
                    .foregroundStyle(Color.inkSecondary)
            }
            Text(finding.verdict.label)
                .font(finding.verdict.isEmphasized ? .rowValue : .rowLabel)
                .foregroundStyle(finding.verdict.tint)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Metrics.rowMinHeight)
        .background(finding.verdict == .danger ? Color.dangerSurface : Color.clear, in: .rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview("危険・要確認・参考") {
    PhotoFindingTable(findings: [
        ReportPhotoFinding(kind: .cardNumber, verdict: .danger, placeCount: 1),
        ReportPhotoFinding(kind: .address, verdict: .caution, placeCount: 2),
        ReportPhotoFinding(kind: .bystanderFace, verdict: .reference, placeCount: 3)
    ])
    .padding()
    .background(Color.ground)
}
