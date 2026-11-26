//
//  DependencyValues+PhotoDispositions.swift
//  PhotoDock
//

import Dependencies

// 写真への対応（問題なし・非表示・削除）の保存先。結果票の「対応済み」の土台。
// preview は空のメモリ上の保存先（「まだ何も対応していない」状態から、押して変わるところを見られる）。
private enum PhotoDispositionRepositoryKey: DependencyKey {
    static let liveValue: any PhotoDispositionRepository = SwiftDataPhotoDispositionRepository()
    static let previewValue: any PhotoDispositionRepository = InMemoryPhotoDispositionRepository()
    static let testValue: any PhotoDispositionRepository = UnimplementedPhotoDispositionRepository()
}

extension DependencyValues {
    var photoDispositions: any PhotoDispositionRepository {
        get { self[PhotoDispositionRepositoryKey.self] }
        set { self[PhotoDispositionRepositoryKey.self] = newValue }
    }
}
