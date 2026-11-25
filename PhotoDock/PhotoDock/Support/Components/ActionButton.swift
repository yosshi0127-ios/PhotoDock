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

    var body: some View {
        Button {
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
        }
        .buttonStyle(.plain)
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
