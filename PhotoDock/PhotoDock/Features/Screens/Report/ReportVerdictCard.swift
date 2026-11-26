//
//  ReportVerdictCard.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の「総合判定」。写真の枚数で数えた結論を、記号（A / B / C）と一緒に出す
struct ReportVerdictCard: View {
    let report: ScanReport

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("総合判定")
                    .font(.label)
                    .foregroundStyle(Color.inkSecondary)
                Text(report.verdictHeadline)
                    .font(.verdict)
                    .foregroundStyle(report.grade.tint)
                // 補足は、見出しだけでは分からないことがあるときだけ出す
                if let note = report.verdictNote {
                    Text(note)
                        .font(.note)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(report.grade.rawValue)
                .font(.verdictGrade)
                .foregroundStyle(report.grade.tint)
                .frame(width: Metrics.gradeDiameter, height: Metrics.gradeDiameter)
                .overlay {
                    Circle().stroke(report.grade.tint, lineWidth: Metrics.gradeStrokeWidth)
                }
                .accessibilityLabel("判定 \(report.grade.rawValue)")
        }
        .padding(Spacing.m)
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("B 要確認あり") {
    ReportVerdictCard(report: .previewCaution)
        .padding()
        .background(Color.ground)
}

#Preview("C 危険あり") {
    ReportVerdictCard(report: .previewDanger)
        .padding()
        .background(Color.ground)
}

#Preview("A 所見なし") {
    ReportVerdictCard(report: .previewClear)
        .padding()
        .background(Color.ground)
}
