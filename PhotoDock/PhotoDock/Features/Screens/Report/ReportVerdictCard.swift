//
//  ReportVerdictCard.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の「総合判定」。写真の枚数で数えた結論を、記号（A / B / C）と一緒に出す
struct ReportVerdictCard: View {
    let report: ScanReport

    /// 丸をどこまで描いたか（0 = まだ / 1 = 描き終えた）。出たときに 0 から 1 へ動かす
    @State private var drawn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("総合判定")
                    .font(.label)
                    .foregroundStyle(Color.inkSecondary)
                Text(report.verdictHeadline)
                    .font(.verdict)
                    .monospacedDigit()
                    .foregroundStyle(report.grade.tint)
                    // 対応して枚数が減るとき、数字が転がる
                    .contentTransition(.numericText())
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
                .contentTransition(.numericText())
                // 記号は、丸が描かれるのに合わせて弾んで出る
                .scaleEffect(drawn ? 1 : 0.6)
                .opacity(drawn ? 1 : 0)
                .frame(width: Metrics.gradeDiameter, height: Metrics.gradeDiameter)
                .overlay {
                    Circle()
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(report.grade.tint, style: StrokeStyle(lineWidth: Metrics.gradeStrokeWidth, lineCap: .round))
                        // 12時の位置から、時計回りに描く
                        .rotationEffect(.degrees(-90))
                }
                .accessibilityLabel("判定 \(report.grade.rawValue)")
        }
        .animation(Motion.quick, value: report.verdictHeadline)
        .animation(Motion.bounce, value: report.grade)
        .onAppear { draw() }
        .padding(Spacing.m)
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
        .accessibilityElement(children: .combine)
    }

    /// 出たときに1回だけ描く。「視差効果を減らす」がオンなら、最初から描き終えた状態で出す
    private func draw() {
        guard !drawn else { return }
        if reduceMotion {
            drawn = true
        } else {
            withAnimation(Motion.draw) { drawn = true }
        }
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
