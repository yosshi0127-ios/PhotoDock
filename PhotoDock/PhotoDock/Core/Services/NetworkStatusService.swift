//
//  NetworkStatusService.swift
//  PhotoDock
//

/// いま通信してよい回線かを判定する。実装は NWPathMonitor。
///
/// 「Wi-Fi 接続時のみダウンロード」の根拠。PhotoKit には回線の種類で絞る指定が無いので自前で見る。
/// 判定できないときは false（通信しない側に倒す。ユーザーの回線を勝手に使わない）
protocol NetworkStatusService: Sendable {
    /// 従量課金でなく（Wi-Fi 等）、低データモードでもない回線に繋がっているか
    func isOnUnmeteredNetwork() async -> Bool
}
