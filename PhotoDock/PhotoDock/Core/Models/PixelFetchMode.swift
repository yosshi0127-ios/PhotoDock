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

    /// 端末に無ければ iCloud から**縮小版**を取る。元ファイル（1枚 1.6MB）ではなく
    /// この長辺以下のサーバ側縮小版（1枚 300KB 前後）を配信させる。Wi-Fi 接続時のみ使う
    case downloadIfNeeded(maxPixelSize: Int)
}
