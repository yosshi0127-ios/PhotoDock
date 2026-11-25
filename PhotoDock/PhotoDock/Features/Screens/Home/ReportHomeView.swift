//
//  ReportHomeView.swift
//  PhotoDock
//

import SwiftUI

/// ホームの本体。前回までの診断を「結果票」として出す（開いただけでは診断しない）
struct ReportHomeView: View {
    let content: ScanHomeContent
    let report: ScanReport
    @Binding var allowsCloudDownload: Bool
    let onScan: () -> Void
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
                    // Text の format: に渡すと画面の言語設定で上書きされるので、文字列にしてから渡す
                    Text("\(date.formatted(Self.dateFormat)) 診断 ・ 診断した写真 \(report.diagnosed.formatted()) 枚")
                } else {
                    Text("診断した写真 \(report.diagnosed.formatted()) 枚")
                }
            }
            .font(.note)
            .foregroundStyle(Color.inkSecondary)
        }
    }

    /// 画面の文言が日本語なので、日付も端末の言語によらず日本語の書き方にそろえる
    /// （英語の端末だと「Nov 25, 2026 診断」と混ざる）
    private static let dateFormat = Date.FormatStyle.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))

    // MARK: - 診断できていない写真

    /// 見ていない写真を「所見なし」に含めない。0枚のときは出さない（不安にさせない）
    @ViewBuilder
    private var undiagnosed: some View {
        if report.undiagnosed > 0 {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if report.notAvailableLocally > 0 {
                    note("未診断 \(report.notAvailableLocally.formatted()) 枚", "iCloud にあり、端末にありません")
                    Toggle("iCloud の写真も診断する", isOn: $allowsCloudDownload)
                        .font(.rowLabel)
                        .tint(Color.themeAccent)
                    Text("Wi-Fi 接続時に取り寄せます（1枚あたり約2MB）")
                        .font(.note)
                        .foregroundStyle(Color.inkSecondary)
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

    /// 次の診断で実際に見る枚数。新しい写真に、取り寄せを許可していれば iCloud のぶんを足す
    private var pendingCount: Int {
        content.newPhotoCount + (allowsCloudDownload ? report.notAvailableLocally : 0)
    }

    private var footer: some View {
        Button {
            onScan()
        } label: {
            Text(pendingCount > 0 ? "\(pendingCount.formatted()) 枚を診断する" : "もう一度診断する")
                .font(.action)
                .foregroundStyle(pendingCount > 0 ? Color.onAccent : Color.themeAccent)
                .frame(maxWidth: .infinity, minHeight: Metrics.actionMinHeight)
                .background(pendingCount > 0 ? Color.themeAccent : Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius)
                        .stroke(Color.themeAccent, lineWidth: Metrics.hairlineWidth)
                }
        }
        .buttonStyle(.plain)
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
    @Previewable @State var allows = false
    ReportHomeView(
        content: .preview(report: .previewCaution), report: .previewCaution,
        allowsCloudDownload: $allows, onScan: {}, onSelect: { _ in }
    )
}

#Preview("C 危険あり・新しい写真 12 枚") {
    @Previewable @State var allows = false
    ReportHomeView(
        content: .preview(report: .previewDanger, newPhotoCount: 12), report: .previewDanger,
        allowsCloudDownload: $allows, onScan: {}, onSelect: { _ in }
    )
}

#Preview("A 所見なし・一部のみ許可") {
    @Previewable @State var allows = false
    ReportHomeView(
        content: .preview(report: .previewClear, access: .limited), report: .previewClear,
        allowsCloudDownload: $allows, onScan: {}, onSelect: { _ in }
    )
}
