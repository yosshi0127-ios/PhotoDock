//
//  ReportHomeView.swift
//  PhotoDock
//

import SwiftUI

/// ホームの本体。前回までの診断を「結果票」として出す（開いただけでは診断しない）
struct ReportHomeView: View {
    let content: ScanHomeContent
    let report: ScanReport
    let onScan: () -> Void
    /// 「iCloud の ◯ 枚も診断する」。確認の画面を出す
    let onCloudScan: () -> Void
    let onSelect: (FindingKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                ReportVerdictCard(report: report)
                ReportTable(items: report.items, onSelect: onSelect)
                undiagnosed
                if content.access == .limited {
                    limitedNotice
                }
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("写真ドック")
                .font(.label)
                .foregroundStyle(Color.inkSecondary)
            Text("診断結果票")
                .font(.screenTitle)
            Group {
                if let date = report.lastScannedAt {
                    Text("\(date.reportDayText) 診断 ・ \(coverageText)")
                } else {
                    Text(coverageText)
                }
            }
            .font(.note)
            .foregroundStyle(Color.inkSecondary)
        }
    }

    /// 見た範囲。診断できていない写真があるときは、全体のうち何枚を見たのかを言う
    /// （「総合判定 B」が、ライブラリの3割だけの結果だと分かるように）
    private var coverageText: String {
        report.undiagnosed > 0
            ? "\(report.total.formatted()) 枚のうち \(report.diagnosed.formatted()) 枚を診断"
            : "診断した写真 \(report.diagnosed.formatted()) 枚"
    }

    // MARK: - 診断できていない写真

    /// 見ていない写真を「所見なし」に含めない。0枚のときは出さない（不安にさせない）
    @ViewBuilder
    private var undiagnosed: some View {
        if report.undiagnosed > 0 {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if report.notAvailableLocally > 0 {
                    note("未診断 \(report.notAvailableLocally.formatted()) 枚", "iCloud にあり、端末にありません")
                    ActionButton(
                        title: "iCloud の \(report.notAvailableLocally.formatted()) 枚も診断する", style: .secondary
                    ) { onCloudScan() }
                }
                if report.failed > 0 {
                    note("診断できなかった \(report.failed.formatted()) 枚", "文字を読み取れませんでした。次の診断でもう一度確認します")
                }
                if report.unavailableInCloud > 0 {
                    note("iCloud から取り出せない \(report.unavailableInCloud.formatted()) 枚", "iCloud 上にデータが見つからない写真です")
                }
                if report.missing > 0 {
                    note("見つからなかった \(report.missing.formatted()) 枚", "読み込めない写真です")
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.cardRadius))
        }
    }

    private func note(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(.sectionTitle)
            Text(detail)
                .font(.note)
                .foregroundStyle(Color.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// 全量を見られていないことは伝える（見えていない分を「無かった」と誤解させない）
    private var limitedNotice: some View {
        Text("選択された写真だけを診断しています。すべてを診断するには、写真へのフルアクセスを許可してください。")
            .font(.note)
            .foregroundStyle(Color.inkSecondary)
    }

    // MARK: - 診断のボタン

    /// 次の診断で実際に見る枚数
    private var pendingCount: Int {
        // iCloud の写真は、下のボタンから別に始める（ここには数えない）
        content.pendingCount(allowsDownload: false)
    }

    private var footer: some View {
        ActionButton(
            title: pendingCount > 0 ? "\(pendingCount.formatted()) 枚を診断する" : "もう一度診断する",
            style: pendingCount > 0 ? .primary : .secondary
        ) { onScan() }
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }
}

private extension ScanHomeContent {
    static func preview(report: ScanReport, access: PhotoLibraryAccess = .full, newPhotoCount: Int = 0) -> ScanHomeContent {
        ScanHomeContent(access: access, assets: [], report: report, flagged: [], newPhotoCount: newPhotoCount)
    }
}

#Preview("B 要確認あり・iCloud に未診断") {
    ReportHomeView(
        content: .preview(report: .previewCaution), report: .previewCaution,
        onScan: {}, onCloudScan: {}, onSelect: { _ in }
    )
}

#Preview("C 危険あり・新しい写真 12 枚") {
    ReportHomeView(
        content: .preview(report: .previewDanger, newPhotoCount: 12), report: .previewDanger,
        onScan: {}, onCloudScan: {}, onSelect: { _ in }
    )
}

#Preview("A 所見なし・一部のみ許可") {
    ReportHomeView(
        content: .preview(report: .previewClear, access: .limited), report: .previewClear,
        onScan: {}, onCloudScan: {}, onSelect: { _ in }
    )
}
