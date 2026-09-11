//
//  DependencyValues+Network.swift
//  PhotoDock
//

import Dependencies

// いま通信してよい回線か（Wi-Fi 等・低データモードでない）。iCloud の写真をダウンロードして
// 診断する前に1回だけ見る。preview は常に Wi-Fi 扱い（トグルをオンにしたときの表示が成立する）。
private enum NetworkStatusServiceKey: DependencyKey {
    static let liveValue: any NetworkStatusService = NWPathMonitorNetworkStatusService()
    static let previewValue: any NetworkStatusService = StubNetworkStatusService()
    static let testValue: any NetworkStatusService = UnimplementedNetworkStatusService()
}

extension DependencyValues {
    var network: any NetworkStatusService {
        get { self[NetworkStatusServiceKey.self] }
        set { self[NetworkStatusServiceKey.self] = newValue }
    }
}
