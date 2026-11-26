//
//  StubPhotoActionService.swift
//  PhotoDock
//

/// Preview 用。PhotoKit には触らず、いつも「実行された」と返す
/// （Preview で、ボタンを押したあとの表示まで見られるようにする）
struct StubPhotoActionService: PhotoActionService {
    func hide(assetID: String) async -> PhotoActionOutcome { .done }
    func delete(assetID: String) async -> PhotoActionOutcome { .done }
}
