//
//  ScanningOrb.swift
//  PhotoDock
//

import SwiftUI

/// 診断中であることを示す、ゆっくり回る点の球。進み具合の数字とは別に、「いま動いている」ことだけを伝える。
/// 「視差効果を減らす」がオンなら、回さずに止まった球を出す
struct ScanningOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let radius = min(size.width, size.height) / 2 - 1
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for index in 0..<Self.count {
                    // 球の表面に、ほぼ均等に点を置く
                    let fraction = (Double(index) + 0.5) / Double(Self.count)
                    let polar = acos(1 - 2 * fraction)
                    let azimuth = Double(index) * Self.goldenAngle + time * 0.9

                    let x = sin(polar) * cos(azimuth)
                    let y = cos(polar)
                    let depth = sin(polar) * sin(azimuth)   // 手前が +1、奥が -1

                    let dot = 1.4 + (depth + 1) * 0.7
                    let point = CGPoint(x: center.x + x * radius, y: center.y + y * radius)
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)),
                        with: .color(Color.themeAccent.opacity(0.25 + (depth + 1) * 0.375))
                    )
                }
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private static let count = 46
    private static let goldenAngle = Double.pi * (3 - 5.0.squareRoot())
    private static let size: CGFloat = 28
}

#Preview {
    ScanningOrb()
        .padding()
        .background(Color.ground)
}
