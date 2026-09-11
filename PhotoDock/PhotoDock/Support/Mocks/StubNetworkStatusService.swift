//
//  StubNetworkStatusService.swift
//  PhotoDock
//

/// Preview 用。回線は見ず、常に「Wi-Fi にいる」ことにする
/// （Preview で「iCloud の写真も診断する」をオンにしたときの表示が成立するように）
struct StubNetworkStatusService: NetworkStatusService {
    func isOnUnmeteredNetwork() async -> Bool {
        true
    }
}
