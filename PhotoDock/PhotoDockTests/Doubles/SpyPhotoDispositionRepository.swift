//
//  SpyPhotoDispositionRepository.swift
//  PhotoDockTests
//

@testable import PhotoDock

/// 呼び出しを記録する `PhotoDispositionRepository`。「読めない」を再現できるようにしてある
actor SpyPhotoDispositionRepository: PhotoDispositionRepository {
    struct Failure: Error {}

    private var stored: [PhotoDisposition]
    private let failsOnLoad: Bool

    private(set) var saved: [PhotoDisposition] = []
    private(set) var removedIDs: [String] = []

    init(dispositions: [PhotoDisposition] = [], failsOnLoad: Bool = false) {
        self.stored = dispositions
        self.failsOnLoad = failsOnLoad
    }

    func allDispositions() throws -> [PhotoDisposition] {
        if failsOnLoad { throw Failure() }
        return stored
    }

    func save(_ disposition: PhotoDisposition) {
        saved.append(disposition)
        stored.removeAll { $0.assetID == disposition.assetID }
        stored.append(disposition)
    }

    func remove(assetID: String) {
        removedIDs.append(assetID)
        stored.removeAll { $0.assetID == assetID }
    }
}
