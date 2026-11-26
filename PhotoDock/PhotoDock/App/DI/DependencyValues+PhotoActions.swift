//
//  DependencyValues+PhotoActions.swift
//  PhotoDock
//

import Dependencies

// 写真ライブラリを書き換える操作（非表示・削除）。
// preview は PhotoKit に触らず、押したあとの表示まで見られるように「実行された」と返す。
private enum PhotoActionServiceKey: DependencyKey {
    static let liveValue: any PhotoActionService = PhotoKitPhotoActionService()
    static let previewValue: any PhotoActionService = StubPhotoActionService()
    static let testValue: any PhotoActionService = UnimplementedPhotoActionService()
}

extension DependencyValues {
    var photoActions: any PhotoActionService {
        get { self[PhotoActionServiceKey.self] }
        set { self[PhotoActionServiceKey.self] = newValue }
    }
}
