//
//  PhotoDetailView.swift
//  PhotoDock
//

import SwiftUI

/// 写真詳細。項目の一覧から開く。記録を表示するだけで、診断はしない（一覧と同じものを見せる）。
/// 写真の上に所見の場所を枠で示し、下に種類ごとの判定を並べる
struct PhotoDetailView: View {
    let photo: ReportItemPhoto
    /// 対応を付け外ししたあとに呼ぶ。開いた元（ホーム・診断中の画面）が、結果票と一覧を作り直す
    var onDispositionChange: () async -> Void = {}

    @State private var state = PhotoDetailState()

    /// 画面のうち、中身を置ける高さ（上の帯と、下のボタンを除く）
    @State private var visibleHeight: CGFloat = 0
    /// 写真のほかに置いているもの（日付・判定の表）の高さ
    @State private var headerHeight: CGFloat = 0
    @State private var tableHeight: CGFloat = 0
    /// 写真を全画面で見ている
    @State private var isZoomed = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                picture
                PhotoFindingTable(findings: state.findings)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tableHeight = $0 }
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        // containerSize は、上の帯と下のボタンを除いたあとの大きさ（実測。ここからさらに引くと、写真が小さくなりすぎる）
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height
        } action: { _, new in
            visibleHeight = new
        }
        .fullScreenCover(isPresented: $isZoomed) {
            if let image = state.image {
                PhotoZoomView(image: image, findings: photo.record.findings)
            }
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) { footer }
        .navigationBarTitleDisplayMode(.inline)
        // 対応を変えた直後は、開いた元の画面が結果票を作り直している。終わるまで、戻る操作を出さない
        .navigationBarBackButtonHidden(state.isWorking || state.isRefreshing)
        .task { await state.show(record: photo.record, isHandled: photo.isHandled) }
    }

    // MARK: - 対処

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            if let removal = state.removal {
                removedNote(removal)
            } else {
                actions
            }
        }
        .disabled(state.isWorking || state.isRefreshing)
        // 対処のあと、ボタンの並びが入れ替わる
        .motion(Motion.settle, value: state.removal)
        .motion(Motion.bounce, value: state.isDismissed)
        .sensoryFeedback(.success, trigger: state.removal) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: state.isDismissed)
        .sensoryFeedback(.error, trigger: state.didFailToRemove || state.didFailToSave) { _, new in new }
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }

    /// 対処のボタン。確認は iOS が出すので、アプリ側では重ねて聞かない
    @ViewBuilder
    private var actions: some View {
        if state.didFailToRemove {
            footnote("変更できませんでした", color: .danger)
        }
        if state.didFailToSave {
            footnote("保存できませんでした", color: .danger)
        }

        if state.isDismissed {
            // 問題なしにしたことを、チェックの記号が弾んで出ることで伝える
            Label("対応済み", systemImage: "checkmark.circle.fill")
                .font(.sectionTitle)
                .foregroundStyle(Color.themeAccent)
                .symbolEffect(.bounce, options: .nonRepeating, value: state.isDismissed)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }

        ActionButton(title: "非表示") { remove(.hide) }
        ActionButton(title: "削除", style: .secondary) { remove(.delete) }
        // 写真を動かさない対応は、控えめに置く（上の2つと取り違えないように）
        Button(state.isDismissed ? "未対応に戻す" : "問題なし") {
            if state.isDismissed { reopen() } else { dismissFindings() }
        }
        .font(.action)
        .foregroundStyle(Color.themeAccent)
        .contentTransition(.interpolate)
        .buttonStyle(PressableButtonStyle())
        .frame(minHeight: Metrics.rowMinHeight)
    }

    /// 非表示・削除したあと。写真はもうアプリから見えないので、戻るだけにする
    @ViewBuilder
    private func removedNote(_ method: RemovePhotoUseCase.Method) -> some View {
        switch method {
        case .hide:
            footnote("非表示にしました", color: .inkSecondary)
        case .delete:
            footnote("削除しました（30日は復元できます）", color: .inkSecondary)
        }
        ActionButton(title: "戻る") { close() }
        // 特定の写真や「非表示」アルバムを直接開く方法は無い。写真アプリを開くところまでで、その先は言葉で案内する
        ActionButton(title: "写真アプリを開く", style: .secondary) { openPhotosApp() }
        if let path = method.disposition.photosAppPath {
            footnote(path, color: .inkSecondary)
        }
    }

    private func footnote(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.note)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }

    // 操作（レイアウトと混ぜないよう、body の外に置く）

    private func remove(_ method: RemovePhotoUseCase.Method) {
        Task {
            await state.perform({
                await state.remove(method, record: photo.record, takenAt: photo.takenAt)
            }, thenRefresh: onDispositionChange)
        }
    }

    private func close() {
        dismiss()
    }

    private func openPhotosApp() {
        openURL(.photosApp)
    }

    private func dismissFindings() {
        Task {
            await state.perform({
                await state.dismiss(record: photo.record, takenAt: photo.takenAt)
            }, thenRefresh: onDispositionChange)
        }
    }

    private func reopen() {
        Task {
            await state.perform({
                await state.reopen(record: photo.record)
            }, thenRefresh: onDispositionChange)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(photo.takenAt?.reportDayText ?? "撮影日不明")
                .font(.screenTitle)
        }
    }

    /// 写真に使える高さ。日付・写真・判定の表が、スクロールせずに1画面に入るようにする。
    /// 縦長の写真をそのまま幅いっぱいに出すと、表が画面の下に押し出されて見えなかった。
    /// 表が長くて入りきらないときは、写真をこれ以上は縮めない（その場合だけスクロールが残る）
    private var pictureMaxHeight: CGFloat? {
        guard visibleHeight > 0 else { return nil }
        // 上下の余白と、日付・写真・表のあいだの間隔
        let chrome = Spacing.m * 4
        return max(Metrics.photoMinHeight, visibleHeight - headerHeight - tableHeight - chrome)
    }

    @ViewBuilder
    private var picture: some View {
        if let image = state.image {
            Button {
                isZoomed = true
            } label: {
                PhotoWithFindings(image: image, findings: photo.record.findings)
                    .clipShape(.rect(cornerRadius: Metrics.tagRadius))
                    // 白い写真だと、地との境が分からなくなる
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.tagRadius)
                            .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
                    }
            }
            .buttonStyle(.plain)
            .disabled(state.removal != nil)
            .accessibilityLabel("写真を大きく表示")
            .frame(maxHeight: pictureMaxHeight)
                // 対処したら、写真はここから消える（非表示: ぼやけて薄れる／削除: 粒になって流れる）
                .blur(radius: state.removal == .hide && !reduceMotion ? 14 : 0)
                .opacity(state.removal == nil ? 1 : 0)
                .background {
                    if let removal = state.removal {
                        removedPlaceholder(removal)
                    }
                }
                .overlay {
                    if state.removal == .delete, !reduceMotion {
                        DustDissolveView(image: image)
                    }
                }
                .animation(reduceMotion ? nil : Motion.settle, value: state.removal)
                .frame(maxWidth: .infinity)
        } else {
            // 読み込み中も、読み込めなかったときも、同じ大きさの枠を置く（下の表が動かないように）
            Group {
                if state.isLoadingImage {
                    ProgressView()
                } else {
                    Text("表示できません")
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .font(.note)
            .frame(maxWidth: .infinity)
            .aspectRatio(4 / 3, contentMode: .fit)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
        }
    }

    /// 写真が消えたあとに、同じ場所に残す記号
    private func removedPlaceholder(_ method: RemovePhotoUseCase.Method) -> some View {
        Image(systemName: method.disposition.symbol)
            .font(.largeTitle)
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
            .accessibilityHidden(true)
    }
}

#Preview("住所・電話番号・郵便番号") {
    NavigationStack {
        PhotoDetailView(photo: ReportItemPhoto.previewAddress[0])
    }
}

#Preview("撮影日不明") {
    NavigationStack {
        PhotoDetailView(photo: ReportItemPhoto.previewAddress[2])
    }
}
