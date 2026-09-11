//
//  SpyNetworkStatusService.swift
//  PhotoDockTests
//

@testable import PhotoDock

/// 呼び出しを記録する `NetworkStatusService`。
/// callCount を残すのは「ダウンロード許可がオフなら回線を見にも行かない」ことを検証するため
actor SpyNetworkStatusService: NetworkStatusService {
    private let unmetered: Bool

    private(set) var callCount = 0

    init(unmetered: Bool) {
        self.unmetered = unmetered
    }

    func isOnUnmeteredNetwork() -> Bool {
        callCount += 1
        return unmetered
    }
}
