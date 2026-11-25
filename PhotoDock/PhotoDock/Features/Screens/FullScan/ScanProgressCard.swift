//
//  ScanProgressCard.swift
//  PhotoDock
//

import SwiftUI

/// 診断の進み具合。「何枚目 / 全部で何枚」と、見積もれるときだけ残り時間を出す
struct ScanProgressCard: View {
    let completed: Int
    let total: Int
    /// 残りの見積もり（秒）。nil なら出さない（始めたばかり・止まっている）
    var remainingSeconds: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(completed.formatted())
                    .font(.verdict)
                Text("/ \(total.formatted()) 枚")
                    .font(.rowLabel)
                    .foregroundStyle(Color.inkSecondary)
                Spacer(minLength: Spacing.s)
                if let remainingText {
                    Text(remainingText)
                        .font(.note)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .monospacedDigit()

            // total が 0 でも割り算が壊れないように下限を 1 にする
            ProgressView(value: Double(min(completed, total)), total: Double(max(1, total)))
                .tint(Color.themeAccent)
                .accessibilityHidden(true)
        }
        .padding(Spacing.m)
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// 分の単位に丸める。見積もりなので、秒まで出すと正確に見えすぎる
    private var remainingText: String? {
        guard let remainingSeconds else { return nil }
        if remainingSeconds < 60 { return "あと 1 分以内" }
        let minutes = Int((remainingSeconds / 60).rounded())
        return "あと約 \(minutes.formatted()) 分"
    }

    private var accessibilityText: String {
        let progress = "\(total.formatted()) 枚のうち \(completed.formatted()) 枚"
        return if let remainingText { "\(progress)、\(remainingText)" } else { progress }
    }
}

#Preview("残り時間あり") {
    ScanProgressCard(completed: 412, total: 853, remainingSeconds: 68)
        .padding()
        .background(Color.ground)
}

#Preview("始めたばかり") {
    ScanProgressCard(completed: 3, total: 3_051)
        .padding()
        .background(Color.ground)
}
