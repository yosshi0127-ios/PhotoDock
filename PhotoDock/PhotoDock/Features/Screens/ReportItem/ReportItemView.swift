//
//  ReportItemView.swift
//  PhotoDock
//

import SwiftUI

/// 結果票の項目（種類）を開いた先。その種類が写っている写真を、1枚1行で並べる。
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

    /// 開いている写真。**行ではなく、この画面が持つ**。
    /// 行に遷移（NavigationLink）をぶら下げると、対応して行が一覧から消えたときに遷移の管理がずれ、
    /// 写真詳細から戻ったあと、この画面の戻るボタンが効かなくなった（実機で発生。brief「段階3で決めたこと」）
    @State private var openedPhoto: ReportItemPhoto?

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
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openedPhoto) { photo in
            PhotoDetailView(photo: photo, onDispositionChange: onDispositionChange)
        }
    }

    private func open(_ photo: ReportItemPhoto) {
        openedPhoto = photo
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
                        ReportItemPhotoRow(photo: photo, openedKind: kind)
                    }
                    .buttonStyle(.plain)
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
