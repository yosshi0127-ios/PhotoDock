//
//  NWPathMonitorNetworkStatusService.swift
//  PhotoDock
//

import Network

struct NWPathMonitorNetworkStatusService: NetworkStatusService {

    /// いまの経路を1回だけ見て判定する。監視し続けはしない
    /// （スキャン開始時に1回判定する用途。途中で切れた分は取得の失敗として次回再挑戦される）
    func isOnUnmeteredNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { path in
                // 最初の通知で判定を終える。handler を外してから cancel しないと、
                // cancel 前にもう一度呼ばれて continuation が二度 resume されうる
                monitor.pathUpdateHandler = nil
                monitor.cancel()

                // isExpensive = モバイル回線やテザリング、isConstrained = 低データモード。
                // どちらも「ユーザーが通信量を気にしている」合図なので通信しない
                let allowed = path.status == .satisfied && !path.isExpensive && !path.isConstrained
                continuation.resume(returning: allowed)
            }

            monitor.start(queue: DispatchQueue(label: "PhotoDock.NetworkStatus"))
        }
    }
}
