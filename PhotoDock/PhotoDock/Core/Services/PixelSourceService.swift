//
//  PixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation

/// 1枚の画像本体（ピクセル）を読む
protocol PixelSourceService: Sendable {

    /// 画像本体のバイト列。端末に元ファイルがあればそれを返す。
    /// 無いときの振る舞いは mode で決まる: localOnly なら notAvailableLocally、
    /// downloadIfNeeded なら iCloud から縮小版を取る（通信の可否は呼び出し側が判断済み）
    func fetchImageData(for id: String, mode: PixelFetchMode) async -> PixelSourceOutcome

    /// 一覧に並べるための縮小画像。取れなければ nil（プレースホルダを出して続ける）。
    /// 診断には使わない — 縮小したものを OCR に通すと精度が落ちるため、
    /// 診断の品質ノブは fetchImageData 側の maxPixelSize が持つ。
    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data?
}
