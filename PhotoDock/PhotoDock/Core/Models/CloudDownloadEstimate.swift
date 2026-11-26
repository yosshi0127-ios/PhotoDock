//
//  CloudDownloadEstimate.swift
//  PhotoDock
//

/// iCloud にある写真を取り寄せる前に見せる見積もり。目安であって、約束ではない
struct CloudDownloadEstimate: Sendable, Equatable {
    /// 取り寄せる枚数
    let photoCount: Int
    /// 通信量の目安（MB）。取り寄せた写真は端末にも保存されるので、使う容量の目安でもある
    let megabytes: Double
    /// かかる時間の目安（秒）
    let seconds: Double
}
