//
//  ReportItemView.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の項目（種類）を開いた先。その種類が写っている写真を並べる。
/// 枚数が少なければ1枚1行（撮った日と、ほかに写っている種類が分かる）、多ければ格子（スクロールが短い）。
/// ホームと診断中の画面で同じものを使う（診断中は、見つかるたびに行が増える）
struct ReportItemView: View {
    let kind: FindingKind
    /// 結果票の、この項目の行（判定と枚数）。まだ結果票が無ければ nil
    let item: ScanReport.Item?
    /// 並び順は Policy が決めてある（危険が先、その中で新しい写真が先）
    let photos: [ReportItemPhoto]
    /// 非表示・削除した写真。対応済みの側に、写真の行の下に並べる（もう読めないので、押せない行）
    var removed: [ReportRemovedPhoto] = []
    /// 写真詳細で対応を付け外ししたあとに呼ぶ（開いた元が、結果票と一覧を作り直す）
    var onDispositionChange: () async -> Void = {}

    /// 対応済みの写真を見ているか。既定は未対応（先に見るべきもの）
    @State private var showsHandled = false

    /// ユーザーが選んだ並べ方。選んでいなければ nil（枚数で決める）
    @State private var chosenLayout: Layout?

    /// 開いている写真。**行ではなく、この画面が持つ**。
    /// 行に遷移（NavigationLink）をぶら下げると、対応して行が一覧から消えたときに遷移の管理がずれ、
    /// 写真詳細から戻ったあと、この画面の戻るボタンが効かなくなった（実機で発生。brief「段階3で決めたこと」）
    @State private var openedPhoto: ReportItemPhoto?

    /// 何枚か選んで、まとめて対応するための状態
    @State private var state = ReportItemState()

    @Environment(\.openURL) private var openURL

    private var openPhotos: [ReportItemPhoto] { photos.filter { !$0.isHandled } }
    private var handledPhotos: [ReportItemPhoto] { photos.filter(\.isHandled) }

    /// 対応済みの枚数（問題なしにした写真 + 非表示・削除した写真）
    private var handledCount: Int { handledPhotos.count + removed.count }

    /// 切り替えを出すのは、未対応と対応済みの両方があるときだけ（片方しか無ければ、選ぶものが無い）
    private var showsPicker: Bool { handledCount > 0 && !openPhotos.isEmpty }

    /// 対応済みの側を見ているか。片方しか無ければ、切り替えの状態によらずそちらを出す。
    /// 「対応済み」を見ている最中に取り消して対応済みが0枚になっても、一覧が空にならないように
    private var isShowingHandled: Bool {
        if handledCount == 0 { return false }
        if openPhotos.isEmpty { return true }
        return showsHandled
    }

    private var shown: [ReportItemPhoto] { isShowingHandled ? handledPhotos : openPhotos }

    /// 選んである写真。選べるのは未対応だけ
    private var selectedPhotos: [ReportItemPhoto] { state.selected(in: openPhotos) }
    private var isBusy: Bool { state.isWorking || state.isRefreshing }

    /// いまの並べ方。選んでいなければ、枚数が多いときだけ格子にする。
    /// 1行ずつだと、顔の写り込み 49枚で6画面ぶんのスクロールになった（実機）。
    /// 少ないときは1行ずつのほうが、撮った日と、ほかに写っている種類が開く前に分かる
    private var layout: Layout {
        chosenLayout ?? (shown.count > Self.gridThreshold ? .grid : .rows)
    }

    private static let gridThreshold = 12
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                if showsPicker {
                    Picker("表示する写真", selection: $showsHandled) {
                        Text("未対応 \(openPhotos.count.formatted())").tag(false)
                        Text("対応済み \(handledCount.formatted())").tag(true)
                    }
                    .pickerStyle(.segmented)
                    // 選んでいる最中は、対応済みの側へ移らせない（選べるのは未対応だけ）
                    .disabled(state.isSelecting)
                }
                list
                if isShowingHandled, !removed.isEmpty {
                    removedList
                }
            }
            .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            // 切り替えたとき・対処して行が移ったときに、一覧をぱっと差し替えない
            .motion(Motion.quick, value: isShowingHandled)
            .motion(Motion.settle, value: shown.map(\.id))
            .motion(Motion.settle, value: layout)
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if state.isSelecting { selectionBar }
        }
        // 選んでいる最中は「戻る」の代わりに「キャンセル」を出す。対応を変えた直後は、
        // 開いた元の画面が結果票を作り直しているので、終わるまで戻る操作を出さない
        .navigationBarBackButtonHidden(state.isSelecting || isBusy)
        .toolbar {
            if state.isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { state.cancelSelection() }
                        .disabled(isBusy)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selectedPhotos.count == openPhotos.count ? "選択を解除" : "すべて選択") {
                        state.toggleAll(openPhotos.map(\.id))
                    }
                    .disabled(isBusy)
                }
            } else {
                // 並べ替えるものが無いとき（写真が0〜1枚）は出さない
                if shown.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(layout.switchLabel, systemImage: layout.switchSymbol) {
                            chosenLayout = layout.other
                        }
                    }
                }
                // まとめて対応できるのは、未対応の写真だけ
                if !isShowingHandled, !openPhotos.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("選択") { state.beginSelection() }
                    }
                }
            }
        }
        .motion(Motion.settle, value: state.isSelecting)
        .sensoryFeedback(.selection, trigger: state.selectedIDs)
        .sensoryFeedback(.error, trigger: state.didFailToRemove || state.didFailToSave) { _, new in new }
        .sensoryFeedback(.selection, trigger: showsHandled)
        .sensoryFeedback(.selection, trigger: chosenLayout)
        .navigationDestination(item: $openedPhoto) { photo in
            PhotoDetailView(photo: photo, onDispositionChange: onDispositionChange)
        }
    }

    /// 写真を押したとき。選んでいる最中は、開かずに選ぶ
    private func open(_ photo: ReportItemPhoto) {
        if state.isSelecting {
            state.toggle(photo.id)
        } else {
            openedPhoto = photo
        }
    }

    // MARK: - まとめて対応

    /// 選んでいる最中に、画面の下に出す。確認は iOS が出すので、アプリ側では重ねて聞かない
    private var selectionBar: some View {
        VStack(spacing: Spacing.xs) {
            if state.didFailToRemove {
                barNote("変更できませんでした", color: .danger)
            }
            if state.didFailToSave {
                barNote("保存できませんでした", color: .danger)
            }
            barNote(
                selectedPhotos.isEmpty ? "写真を選んでください" : "\(selectedPhotos.count.formatted()) 枚を選択中",
                color: .inkSecondary
            )
            .contentTransition(.numericText())

            HStack(spacing: Spacing.xs) {
                ActionButton(title: "非表示", style: .secondary) { remove(.hide) }
                ActionButton(title: "削除", style: .secondary) { remove(.delete) }
                ActionButton(title: "問題なし") { dismissSelected() }
            }
            .disabled(selectedPhotos.isEmpty || isBusy)
            .opacity(selectedPhotos.isEmpty ? 0.4 : 1)
        }
        .motion(Motion.quick, value: selectedPhotos.count)
        .frame(maxWidth: Metrics.readableWidth)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.ground)
    }

    private func barNote(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.note)
            .foregroundStyle(color)
    }

    private func dismissSelected() {
        let photos = selectedPhotos
        Task {
            await state.perform({ await state.dismiss(photos) }, thenRefresh: onDispositionChange)
        }
    }

    private func remove(_ method: RemovePhotoUseCase.Method) {
        let photos = selectedPhotos
        Task {
            await state.perform({ await state.remove(method, photos) }, thenRefresh: onDispositionChange)
        }
    }

    /// 選んでいる最中に、写真に重ねる印
    private func selectionMark(_ photo: ReportItemPhoto) -> some View {
        let isSelected = state.selectedIDs.contains(photo.id)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.themeAccent : Color.inkSecondary)
            .background(Color.surface, in: .circle)
            .accessibilityHidden(true)
    }

    /// 写真アプリの中での行き先。非表示が先、削除が後（一覧にある対処だけ）
    private var removedPaths: [String] {
        [PhotoDisposition.Action.hidden, .deleted]
            .filter { action in removed.contains { $0.action == action } }
            .compactMap(\.photosAppPath)
    }

    private func openPhotosApp() {
        openURL(.photosApp)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(kind.label)
                .font(.screenTitle)
            if let item {
                Text("\(item.verdict.label) \(item.displayCount.formatted()) 枚")
                    .font(.sectionTitle)
                    .foregroundStyle(item.verdict.tint)
            }
            if let note = kind.itemNote {
                Text(note)
                    .font(.note)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    /// 非表示・削除した写真。アプリからはもう読めないので、押せない行で出す。
    /// 見に行く先は写真アプリなので、開くボタンを下に置く
    private var removedList: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            VStack(spacing: 0) {
                ForEach(removed) { photo in
                    if photo.id != removed.first?.id {
                        Divider().overlay(Color.hairline)
                    }
                    ReportRemovedPhotoRow(photo: photo, openedKind: kind)
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
            .clipShape(.rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
            }

            ActionButton(title: "写真アプリを開く", style: .secondary) { openPhotosApp() }
            // 直接は開けないので、行き方を添える。並んでいる対処のぶんだけ出す
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(removedPaths, id: \.self) { path in
                    Text(path)
                }
            }
            .font(.note)
            .foregroundStyle(Color.inkSecondary)
        }
    }

    @ViewBuilder
    private var list: some View {
        if shown.isEmpty, isShowingHandled {
            // 対応済みが、非表示・削除した写真だけのとき。下の注記が中身になる
            EmptyView()
        } else if shown.isEmpty {
            Text("写真はありません")
                .font(.note)
                .foregroundStyle(Color.inkSecondary)
        } else if layout == .grid {
            // 画面に出た分だけを作る（サムネイルの読み込みも1枚ごと）
            LazyVGrid(columns: Self.gridColumns, spacing: Spacing.xxs) {
                ForEach(shown) { photo in
                    Button {
                        open(photo)
                    } label: {
                        ReportItemPhotoCell(photo: photo)
                            .overlay(alignment: .bottomTrailing) {
                                if state.isSelecting {
                                    selectionMark(photo).padding(Spacing.xxs)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(state.selectedIDs.contains(photo.id) ? .isSelected : [])
                }
            }
        } else {
            // 数十〜数百行になりうるので、画面に出た行だけを作る（サムネイルの読み込みも行ごと）
            LazyVStack(spacing: 0) {
                ForEach(shown) { photo in
                    if photo.id != shown.first?.id {
                        Divider().overlay(Color.hairline)
                    }
                    Button {
                        open(photo)
                    } label: {
                        HStack(spacing: 0) {
                            if state.isSelecting {
                                selectionMark(photo).padding(.leading, Spacing.s)
                            }
                            ReportItemPhotoRow(photo: photo, openedKind: kind)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(state.selectedIDs.contains(photo.id) ? .isSelected : [])
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
            .clipShape(.rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Color.hairline, lineWidth: Metrics.hairlineWidth)
            }
        }
    }
}

#Preview("住所・要確認") {
    NavigationStack {
        ReportItemView(
            kind: .address,
            item: ScanReport.Item(kind: .address, verdict: .caution, photoCount: 3),
            photos: ReportItemPhoto.previewAddress
        )
    }
}

#Preview("認証情報・危険あり") {
    NavigationStack {
        ReportItemView(
            kind: .credential,
            item: ScanReport.Item(kind: .credential, verdict: .danger, photoCount: 2),
            photos: ReportItemPhoto.previewCredential
        )
    }
}
