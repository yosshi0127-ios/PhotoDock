//
//  BurstView.swift
//  PhotoDock
//

import SwiftUI

/// まわりに小さな粒が1回はじける。総合判定が A になったときに使う。
/// `trigger` の値が変わるたびに1回流す。それ以外のあいだは何も描かない
struct BurstView: View {
    let trigger: Int
    var color: Color = .themeAccent

    @State private var startedAt: Date?

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                guard let startedAt else { return }
                let progress = timeline.date.timeIntervalSince(startedAt) / Self.duration
                guard progress < 1 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let eased = 1 - pow(1 - progress, 3)
                for index in 0..<Self.count {
                    let angle = Double(index) / Double(Self.count) * 2 * .pi
                    // 1つおきに、長さと太さを変える
                    let reach = index.isMultiple(of: 2) ? 1.0 : 0.72
                    let distance = radius * (0.55 + 0.45 * eased * reach)
                    let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                    let dot = (index.isMultiple(of: 2) ? 5.0 : 3.5) * (1 - progress * 0.6)
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)),
                        with: .color(color.opacity(1 - progress))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            // 最初に出たとき（まだ1回も頼まれていない）は流さない
            guard trigger > 0 else { return }
            startedAt = .now
            // 流し終えたら止める（描くものが無いのに、毎コマ呼ばれ続けないように）
            try? await Task.sleep(for: .seconds(Self.duration))
            if !Task.isCancelled { startedAt = nil }
        }
    }

    private static let duration: TimeInterval = 0.8
    private static let count = 14
}

#Preview {
    @Previewable @State var trigger = 0
    Button("はじける") { trigger += 1 }
        .frame(width: 120, height: 120)
        .overlay { BurstView(trigger: trigger).frame(width: 160, height: 160) }
}
