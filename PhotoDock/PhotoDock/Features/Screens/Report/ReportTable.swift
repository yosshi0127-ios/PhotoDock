//
//  ReportTable.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の表。項目（種類）ごとに判定と枚数を並べる。
///
/// 枚数は「その種類が写っている写真の枚数」。1枚に複数の種類が写っていれば、それぞれの行に数える。
/// ホームと診断中の画面で同じものを使う
struct ReportTable: View {
    let items: [ScanReport.Item]
    /// まだ結果が出そろっていないときに、所見のない行へ出す言葉（「確認中」など）。
    /// 診断の途中で「所見なし」と書くと、見ていない写真まで問題なしと読めてしまう。nil なら「所見なし」
    var pendingLabel: String?
    /// 行を押したとき。nil なら押せない表として出す。所見のない行は常に押せない
    var onSelect: ((FindingKind) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header

            ForEach(items) { item in
                Divider().overlay(Color.hairline)

                if let onSelect, item.hasPhotos {
                    Button {
                        onSelect(item.kind)
                    } label: {
                        row(item, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    row(item, showsChevron: false)
                }
            }
        }
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .clipShape(.rect(cornerRadius: Metrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            Text("項目")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("判定")
                .frame(minWidth: Self.verdictWidth, alignment: .leading)
            Text("枚数")
                .frame(minWidth: Self.countWidth, alignment: .trailing)
            chevron.hidden()
        }
        .font(.label)
        .foregroundStyle(Color.inkSecondary)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        // 形を明示する。省くと iOS 26 では角の丸い面で塗られ、行ごとに丸く見える
        .background(Color.surfaceMuted, in: .rect)
        .accessibilityHidden(true)
    }

    private func row(_ item: ScanReport.Item, showsChevron: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Text(item.kind.label)
                .font(item.verdict == .danger ? .rowValue : .rowLabel)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verdictLabel(item))
                .font(item.verdict.isEmphasized ? .rowValue : .rowLabel)
                .foregroundStyle(isPending(item) ? Color.inkSecondary : item.verdict.tint)
                .frame(minWidth: Self.verdictWidth, alignment: .leading)
            Text(item.displayCount.formatted())
                .font(item.photoCount > 0 ? .rowValue : .rowLabel)
                .monospacedDigit()
                .foregroundStyle(item.photoCount > 0 ? Color.ink : Color.inkSecondary)
                .frame(minWidth: Self.countWidth, alignment: .trailing)
            chevron.opacity(showsChevron ? 1 : 0)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Metrics.rowMinHeight)
        .background(item.verdict == .danger ? Color.dangerSurface : Color.clear, in: .rect)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.kind.label)、\(verdictLabel(item))、\(item.displayCount.formatted()) 枚")
    }

    /// 所見のない行で、まだ結果が出そろっていない
    private func isPending(_ item: ScanReport.Item) -> Bool {
        pendingLabel != nil && item.verdict == .clear
    }

    private func verdictLabel(_ item: ScanReport.Item) -> String {
        if let pendingLabel, item.verdict == .clear { pendingLabel } else { item.verdict.label }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
            .accessibilityHidden(true)
    }

    /// 「所見なし」「要確認」が1行に収まる幅。文字が大きい設定ではこれより広がる（minWidth）
    private static let verdictWidth: CGFloat = 64
    private static let countWidth: CGFloat = 36
}

#Preview("B 要確認あり") {
    ReportTable(items: ScanReport.previewCaution.items) { _ in }
        .padding()
        .background(Color.ground)
}

#Preview("C 危険あり") {
    ReportTable(items: ScanReport.previewDanger.items) { _ in }
        .padding()
        .background(Color.ground)
}

#Preview("診断中（所見のない行は確認中）") {
    ReportTable(items: ScanReport.previewCaution.items, pendingLabel: "確認中") { _ in }
        .padding()
        .background(Color.ground)
}
