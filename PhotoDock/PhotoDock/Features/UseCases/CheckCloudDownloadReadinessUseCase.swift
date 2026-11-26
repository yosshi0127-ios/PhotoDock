//
//  CheckCloudDownloadReadinessUseCase.swift
//  PhotoDock
//

import Dependencies

/// iCloud の写真を取り寄せてよい回線か（Wi-Fi で、低データモードでない）。
/// 診断を始める**前に**確かめる。始めてから黙って取り寄せないまま終わると、
/// 「診断したのに未診断のまま」になり、理由が分からない
struct CheckCloudDownloadReadinessUseCase: Sendable {
    @Dependency(\.network) private var network

    func callAsFunction() async -> Bool {
        await network.isOnUnmeteredNetwork()
    }
}
