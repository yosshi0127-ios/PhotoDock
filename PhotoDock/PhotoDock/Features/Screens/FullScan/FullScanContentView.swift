//
//  FullScanContentView.swift
//  PhotoDock
//

import SwiftUI

/// 診断の画面の見た目。状態を受け取って描くだけで、診断そのものは持たない
/// （`FullScanView` が State とつなぐ。こちらは Preview で各状態を並べられる）。
///
/// 診断中は結果票の表が埋まっていき、終わるとその場で総合判定が出る
struct FullScanContentView: View {
    let phase: FullScanState.Phase
    let total: Int
    var remainingSeconds: Double?
    var elapsedSeconds: Double = 0
    let onSelect: (FindingKind) -> Void
    let onStop: () -> Void
    let onResume: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                sections
            }
            // 診断中 → 完了・中断 で中身が入れ替わるとき、ぱっと切り替えない
            .motion(Motion.settle, value: stage)
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) { footer }
        // 終わった・止まったことを、指にも伝える
        .sensoryFeedback(trigger: stage) { _, new in
            new == 2 ? .success : new == 1 ? .warning : nil
        }
    }

    /// 画面の段階（結果票の中身ではなく、どの段階か）。入れ替わりの動きのきっかけにする
    private var stage: Int {
        switch phase {
        case .idle, .scanning: 0
        case .interrupted: 1
        case .finished: 2
        }
    }

    // MARK: - 見出し

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.screenTitle)
                .contentTransition(.interpolate)
            if let subtitle {
                Text(subtitle)
                    .font(.note)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var title: String {
        switch phase {
        case .idle, .scanning: "診断中"
        case .interrupted: "中断"
        case .finished: "診断完了"
        }
    }

    private var subtitle: String? {
        switch phase {
        case .idle, .scanning:
            nil
        case let .interrupted(report):
            "残り \((total - report.total).formatted()) 枚"
        case let .finished(report):
            "\(report.total.formatted()) 枚 ・ \(elapsedText)"
        }
    }

    /// 1分未満は秒、それ以上は分と秒
    private var elapsedText: String {
        let seconds = Int(elapsedSeconds.rounded())
        return seconds < 60 ? "\(seconds) 秒" : "\(seconds / 60) 分 \(seconds % 60) 秒"
    }

    // MARK: - 本文

    @ViewBuilder
    private var sections: some View {
        switch phase {
        case .idle:
            ScanProgressCard(completed: 0, total: total)

        case let .scanning(report):
            ScanProgressCard(completed: report.total, total: total, remainingSeconds: remainingSeconds)
            ReportTable(items: report.items, pendingLabel: "確認中", onSelect: onSelect)
            notice("アプリは開いたままに")

        case let .interrupted(report):
            ScanProgressCard(completed: report.total, total: total)
            // 途中までの結果。所見のない行を「所見なし」と書くと、見ていない写真まで問題なしと読める
            ReportTable(items: report.items, pendingLabel: "未完了", onSelect: onSelect)

        case let .finished(report):
            ReportVerdictCard(report: report)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            ReportTable(items: report.items, onSelect: onSelect)
            if report.undiagnosed > 0 {
                // 内訳（iCloud にある・読み取れなかった等）と対処は、結果票のほうに出す
                notice("未診断 \(report.undiagnosed.formatted()) 枚")
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
        }
        .font(.note)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.cardRadius))
    }

    // MARK: - 下のボタン

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            switch phase {
            case .idle, .scanning:
                ActionButton(title: "中断", style: .secondary) { onStop() }
            case .interrupted:
                ActionButton(title: "続きを診断") { onResume() }
                ActionButton(title: "結果票へ", style: .secondary) { onClose() }
            case .finished:
                ActionButton(title: "結果票へ") { onClose() }
            }
        }
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }
}

private extension FullScanContentView {
    /// Preview 用。操作は何もしない
    init(phase: FullScanState.Phase, total: Int, remainingSeconds: Double? = nil, elapsedSeconds: Double = 0) {
        self.init(
            phase: phase, total: total, remainingSeconds: remainingSeconds, elapsedSeconds: elapsedSeconds,
            onSelect: { _ in }, onStop: {}, onResume: {}, onClose: {}
        )
    }
}

#Preview("診断中") {
    FullScanContentView(phase: .scanning(.previewCaution), total: 3_051, remainingSeconds: 68)
}

#Preview("止まった") {
    FullScanContentView(phase: .interrupted(.previewCaution), total: 3_051)
}

#Preview("終わった・C 危険あり") {
    FullScanContentView(phase: .finished(.previewDanger), total: 1_204, elapsedSeconds: 128)
}

#Preview("終わった・診断できていない写真あり") {
    FullScanContentView(phase: .finished(.previewCaution), total: 3_051, elapsedSeconds: 41)
}
