//
//  PixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation

/// 1枚の画像本体（ピクセル）を読む
protocol PixelSourceService: Sendable {

    /// 元ファイルのバイト列をそのまま返す
    func fetchImageData(for id: String) async -> PixelSourceOutcome

    /// 一覧に並べるための縮小画像。取れなければ nil（プレースホルダを出して続ける）。
    /// 診断には使わない — 縮小したものを OCR に通すと精度が落ちるため、
    /// 診断の品質ノブは fetchImageData 側の maxPixelSize が持つ。
    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data?
}
