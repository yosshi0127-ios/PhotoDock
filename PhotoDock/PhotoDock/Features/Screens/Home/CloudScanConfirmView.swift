//
//  CloudScanConfirmView.swift
//  PhotoDock
//

import SwiftUI

/// iCloud にある写真を取り寄せて診断する前の確認。
/// 通信量・時間・端末に保存されることを見せてから、始めてもらう（数GB の通信を黙って始めない）
struct CloudScanConfirmView: View {
    let estimate: CloudDownloadEstimate
    /// 始めようとしたが、Wi-Fi でなかった
    let isOffWiFi: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("iCloud の写真を診断")
                    .font(.screenTitle)

                figures

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    point("Wi-Fi のみ")
                    // 消すと、数GB が端末に入ることを黙って始めることになる
                    point("端末にも保存されます")
                }
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.m)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var figures: some View {
        VStack(spacing: 0) {
            figure("写真", "\(estimate.photoCount.formatted()) 枚")
            Divider().overlay(Color.hairline)
            figure("通信量", estimate.sizeText)
            Divider().overlay(Color.hairline)
            figure("時間", estimate.durationText)
        }
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .clipShape(.rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.s) {
            Text(label)
                .font(.rowLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.rowValue)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Metrics.rowMinHeight)
        .accessibilityElement(children: .combine)
    }

    private func point(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
        }
        .font(.note)
        .foregroundStyle(Color.inkSecondary)
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            if isOffWiFi {
                Text("Wi-Fi に接続してください")
                    .font(.note)
                    .foregroundStyle(Color.danger)
                    .multilineTextAlignment(.center)
            }
            ActionButton(title: "取り寄せて診断") { onStart() }
            ActionButton(title: "やめる", style: .secondary) { onCancel() }
        }
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }
}

#Preview("2,169 枚") {
    CloudScanConfirmView(
        estimate: CloudDownloadPolicy().estimate(photoCount: 2_169), isOffWiFi: false, onStart: {}, onCancel: {}
    )
}

#Preview("Wi-Fi でない") {
    CloudScanConfirmView(
        estimate: CloudDownloadPolicy().estimate(photoCount: 20), isOffWiFi: true, onStart: {}, onCancel: {}
    )
}
