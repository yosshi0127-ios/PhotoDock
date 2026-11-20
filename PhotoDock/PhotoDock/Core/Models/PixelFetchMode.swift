//
//  PixelFetchMode.swift
//  PhotoDock
//

/// 画像本体をどこまで取りに行くか。
/// 「ダウンロードしてよいか」はユーザーの設定と回線で決まる呼び出し側の判断なので、
/// pixelSource 自身が持たず、引数で受ける。
enum PixelFetchMode: Sendable, Equatable {
    /// 端末にあるものだけ。通信しない（既定）
    case localOnly

    /// 端末に無ければ iCloud から取り寄せる。この長辺を満たす大きさを配信させる。Wi-Fi 接続時のみ使う。
    /// 通信量は要求する長辺で段階的に変わる（実機で Wi-Fi の受信量を計測・2026-11-20）:
    /// 2,048px 以下は1枚 約 0.8MB の縮小版、3,000px は縮小版では足りず 約 1.9MB（元ファイル並み）
    case downloadIfNeeded(maxPixelSize: Int)
}
