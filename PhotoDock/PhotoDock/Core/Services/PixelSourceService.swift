//
//  PixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// 1枚の画像本体（ピクセル）を読む
protocol PixelSourceService: Sendable {
    
    /// 元ファイルのバイト列をそのまま返す
    func fetchImageData(for id: String) async -> PixelSourceOutcome
}
