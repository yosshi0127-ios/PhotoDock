//
//  InMemoryPhotoDispositionRepository.swift
//  PhotoDock
//

/// Preview 用のメモリ上の対応状況。SwiftData には触らない。
/// 返す順は assetID 順（辞書の順序はプロセスごとに変わるので、Preview の表示が揺れないように）
actor InMemoryPhotoDispositionRepository: PhotoDispositionRepository {
    private var storage: [String: PhotoDisposition]

    init(dispositions: [PhotoDisposition] = []) {
        storage = Dictionary(dispositions.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })
    }

    func allDispositions() -> [PhotoDisposition] {
        storage.values.sorted { $0.assetID < $1.assetID }
    }

    func save(_ disposition: PhotoDisposition) {
        storage[disposition.assetID] = disposition
    }

    func remove(assetID: String) {
        storage[assetID] = nil
    }
}
