//
//  PixelSourceOutcome.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation

/// 1枚のピクセル取得の結果
enum PixelSourceOutcome: Sendable, Equatable {
    /// 元ファイルのバイト列（EXIF の向き情報を含む）
    case data(Data)
    /// 端末に元ファイルがない（iCloud 最適化）。診断せず「未診断」として記録する
    case notAvailableLocally
    /// 見つからない・読めない。
    case missing
}
