//
//  ReportItemState.swift
//  PhotoDock
//

import Observation

/// 項目の一覧の状態。写真を何枚か選んで、まとめて対応する。
/// 選べるのは未対応の写真だけ（対応済みを戻すのは、写真詳細から1枚ずつ）
@MainActor
@Observable
final class ReportItemState {
    /// 選んでいる最中か。その間は、写真を押すと開かずに選ぶ
    private(set) var isSelecting = false

    private(set) var selectedIDs: Set<String> = []

    /// iOS の確認に答えるのを待っている・保存している。その間は、ほかの操作をさせない
    private(set) var isWorking = false

    /// 対応を変えたあと、開いた元の画面が結果票を作り直している。その間は、戻る操作を出さない
    /// （写真詳細と同じ理由。実機では、作り直しの最中に押した「戻る」が効かなかった）
    private(set) var isRefreshing = false

    /// 非表示・削除ができなかった（ユーザーがやめた場合は含めない）
    private(set) var didFailToRemove = false

    /// 対応を保存できなかった
    private(set) var didFailToSave = false

    // 依存は UseCase 経由のみ
    private let dismissPhotos = DismissPhotosUseCase()
    private let removePhotos = RemovePhotosUseCase()

    func beginSelection() {
        isSelecting = true
        selectedIDs = []
        didFailToRemove = false
        didFailToSave = false
    }

    func cancelSelection() {
        isSelecting = false
        selectedIDs = []
    }

    func toggle(_ id: String) {
        guard isSelecting, !isWorking else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    /// 全部選ぶ。全部選んであれば、全部外す
    func toggleAll(_ ids: [String]) {
        guard isSelecting, !isWorking else { return }
        selectedIDs = selectedIDs.isSuperset(of: ids) ? [] : Set(ids)
    }

    /// いま一覧にある写真のうち、選んであるもの（一覧から消えた写真の印は数えない）
    func selected(in photos: [ReportItemPhoto]) -> [ReportItemPhoto] {
        photos.filter { selectedIDs.contains($0.id) }
    }

    /// 選んだ写真を、まとめて「問題なし」にする
    func dismiss(_ photos: [ReportItemPhoto]) async {
        guard !isWorking, !photos.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await dismissPhotos(photos: photos)
            didFailToSave = false
            cancelSelection()
        } catch {
            didFailToSave = true
        }
    }

    /// 選んだ写真を、まとめて非表示にする・削除する。やめたときは、選んだまま残す
    func remove(_ method: RemovePhotoUseCase.Method, _ photos: [ReportItemPhoto]) async {
        guard !isWorking, !photos.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        switch await removePhotos(method, photos: photos) {
        case .done:
            didFailToRemove = false
            cancelSelection()
        case .cancelled:
            didFailToRemove = false
        case .notFound, .failed:
            didFailToRemove = true
        }
    }

    /// 対応を変える操作を、開いた元の画面の作り直しが終わるまでをひとまとまりにして行う
    func perform(_ change: () async -> Void, thenRefresh refresh: () async -> Void) async {
        isRefreshing = true
        defer { isRefreshing = false }
        await change()
        await refresh()
    }
}
