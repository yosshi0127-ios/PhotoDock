//
//  WelcomeView.swift
//  PhotoDock
//

import SwiftUI

/// まだ1枚も診断していないときの案内。3つの約束を見せてから、診断を始めてもらう。
///
/// アクセスをまだ聞いていない場合は、**この画面のボタンを押してから**確認が出る
/// （いきなり確認を出すと、何をするアプリか分からないまま許可を求めることになる）
struct WelcomeView: View {
    enum Mode: Equatable {
        /// アクセスをまだ聞いていない
        case needsPermission
        /// 許可済みで、まだ診断していない。診断できる枚数を出す
        case firstScan(photoCount: Int)
    }

    let mode: Mode
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("写真ドック")
                        .font(.label)
                        .foregroundStyle(Color.inkSecondary)
                    Text("カメラロールの\n検診をはじめます")
                        .font(.screenTitle)
                    Text("カード番号や住所など、人に見られると困るものが写った写真を探して、結果票にまとめます。")
                        .font(.rowLabel)
                        .foregroundStyle(Color.inkSecondary)
                }

                promises
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var promises: some View {
        VStack(spacing: 0) {
            promise("端末の中だけで診断します", "写真を外に送ることはありません。")
            Divider().overlay(Color.hairline)
            promise("写真は書き換えません", "診断で写真が変わることはありません。")
            Divider().overlay(Color.hairline)
            promise("読み取った文字は残しません", "記録するのは、種類と場所だけです。")
        }
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
    }

    private func promise(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.themeAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.sectionTitle)
                Text(detail)
                    .font(.note)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            switch mode {
            case .needsPermission:
                ActionButton(title: "診断をはじめる") { onStart() }
                Text("次に、写真へのアクセスを確認します。")
                    .font(.note)
                    .foregroundStyle(Color.inkSecondary)
            case .firstScan(photoCount: 0):
                Text("診断できる写真がありません")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.inkSecondary)
            case let .firstScan(photoCount: count):
                ActionButton(title: "\(count.formatted()) 枚を診断する") { onStart() }
            }
        }
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }
}

#Preview("アクセスを聞く前") {
    WelcomeView(mode: .needsPermission) {}
}

#Preview("許可済み・まだ診断していない") {
    WelcomeView(mode: .firstScan(photoCount: 3_051)) {}
}

#Preview("写真が無い") {
    WelcomeView(mode: .firstScan(photoCount: 0)) {}
}
