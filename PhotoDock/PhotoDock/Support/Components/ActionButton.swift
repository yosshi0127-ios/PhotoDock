//
//  ActionButton.swift
//  PhotoDock
//

import SwiftUI

/// 画面の下に置く、幅いっぱいのボタン。主ボタン（塗り）と副ボタン（枠）の2種類
struct ActionButton: View {
    enum Style {
        /// その画面でいちばん押してほしい操作
        case primary
        /// もう一方の操作（中断・戻る）
        case secondary
    }

    let title: String
    var style: Style = .primary
    let action: () -> Void

    /// 押した回数。振動のきっかけにする
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Text(title)
                .font(.action)
                .foregroundStyle(style == .primary ? Color.onAccent : Color.themeAccent)
                .frame(maxWidth: .infinity, minHeight: Metrics.actionMinHeight)
                .background(
                    style == .primary ? Color.themeAccent : Color.surface,
                    in: .rect(cornerRadius: Metrics.cardRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius)
                        .stroke(Color.themeAccent, lineWidth: Metrics.hairlineWidth)
                }
                // 文言が変わるとき（「◯ 枚を診断」→「もう一度診断」）は、ぱっと差し替えずに切り替える
                .contentTransition(.interpolate)
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// 押しているあいだ少し縮み、離すとばねで戻る。押せたことが指に返る
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressedScale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.xs) {
        ActionButton(title: "続きを診断する") {}
        ActionButton(title: "中断する", style: .secondary) {}
    }
    .padding()
    .background(Color.ground)
}
