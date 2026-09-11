//
//  PixelSourceOutcome.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation

/// 1枚のピクセル取得の結果
enum PixelSourceOutcome: Sendable, Equatable {
    /// 元ファイル、または iCloud から取った縮小版のバイト列（EXIF の向き情報を含む）
    case data(Data)
    /// 端末に元ファイルがなく、ダウンロードは許可されていない（iCloud 最適化）。
    /// ユーザーが「iCloud の写真も診断する」をオンにすれば解決しうる状態
    case notAvailableLocally
    /// ダウンロードを試したが iCloud 側にも実体が無かった（"Record not found"）。
    /// ユーザーにもアプリにもできることは無い。写真アプリでも開けないことがある
    case unavailableInCloud
    /// 見つからない・読めない。
    case missing
}
