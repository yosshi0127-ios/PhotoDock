//
//  SpyPhotoActionService.swift
//  PhotoDockTests
//

@testable import PhotoDock

/// 呼び出しを記録する `PhotoActionService`。返す結果を指定できる（やめた・できなかった を再現する）
actor SpyPhotoActionService: PhotoActionService {
    private let outcome: PhotoActionOutcome

    private(set) var hiddenIDs: [String] = []
    private(set) var deletedIDs: [String] = []

    init(outcome: PhotoActionOutcome = .done) {
        self.outcome = outcome
    }

    func hide(assetID: String) -> PhotoActionOutcome {
        hiddenIDs.append(assetID)
        return outcome
    }

    func delete(assetID: String) -> PhotoActionOutcome {
        deletedIDs.append(assetID)
        return outcome
    }
}
