//
//  CloudDownloadPolicy.swift
//  PhotoDock
//

/// iCloud にある写真を取り寄せて診断するときの、通信量と時間の見積もり。純粋関数のみ。
///
/// 数字は実機の実測（iPhone 15 Pro Max・長辺 3,000px の要求。brief「iCloud 最適化への対応」）:
/// - 通信量: Wi-Fi の受信量で 1枚 約 1.87MB（2026-11-20・20枚）
/// - 時間: 1枚 約 0.84秒（2026-11-20 と 2026-11-26 の2回とも同じ）
///
/// **取り寄せた写真は端末にも保存される**（2026-11-26・20枚を取り寄せたあと、通信を禁止して読み直すと
/// 20枚とも端末から読めた）。なので、通信量の見積もりは、端末で使う容量の目安にもなる
struct CloudDownloadPolicy: Sendable {
    let megabytesPerPhoto: Double
    let secondsPerPhoto: Double

    init(megabytesPerPhoto: Double = 1.87, secondsPerPhoto: Double = 0.84) {
        self.megabytesPerPhoto = megabytesPerPhoto
        self.secondsPerPhoto = secondsPerPhoto
    }

    func estimate(photoCount: Int) -> CloudDownloadEstimate {
        let count = max(0, photoCount)
        return CloudDownloadEstimate(
            photoCount: count,
            megabytes: Double(count) * megabytesPerPhoto,
            seconds: Double(count) * secondsPerPhoto
        )
    }
}
