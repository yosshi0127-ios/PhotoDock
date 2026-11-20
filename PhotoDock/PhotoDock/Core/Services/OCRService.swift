//
//  OCRService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation

/// 画像のバイト列から文字を読む
protocol OCRService: Sendable {    
    /// 確度による切り捨てはしない（低確度を捨てるかは Policy が決める）
    ///
    /// 読めなかったときは空配列ではなく `.failed` を返す
    /// （空配列は「文字が無かった」の意味で、診断済みとして記録される）
    func recognizeText(in data: Data, maxPixelSize: Int) async -> OCROutcome
}

