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

    /// 何回呼ばれたか（まとめて1回で渡していることを確かめる）
    private(set) var callCount = 0

    func hide(assetIDs: [String]) -> PhotoActionOutcome {
        callCount += 1
        hiddenIDs.append(contentsOf: assetIDs)
        return outcome
    }

    func delete(assetIDs: [String]) -> PhotoActionOutcome {
        callCount += 1
        deletedIDs.append(contentsOf: assetIDs)
        return outcome
    }
}
