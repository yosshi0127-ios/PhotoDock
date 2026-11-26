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
    private let failsOnSave: Bool

    private(set) var saved: [PhotoDisposition] = []
    private(set) var removedIDs: [String] = []

    init(dispositions: [PhotoDisposition] = [], failsOnLoad: Bool = false, failsOnSave: Bool = false) {
        self.stored = dispositions
        self.failsOnLoad = failsOnLoad
        self.failsOnSave = failsOnSave
    }

    func allDispositions() throws -> [PhotoDisposition] {
        if failsOnLoad { throw Failure() }
        return stored
    }

    func save(_ disposition: PhotoDisposition) throws {
        if failsOnSave { throw Failure() }
        saved.append(disposition)
        stored.removeAll { $0.assetID == disposition.assetID }
        stored.append(disposition)
    }

    func remove(assetID: String) throws {
        if failsOnSave { throw Failure() }
        removedIDs.append(assetID)
        stored.removeAll { $0.assetID == assetID }
    }
}
