//
//  RecognizedText.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// OCRが返す認識結果
struct RecognizedText: Sendable, Equatable {
    let text: String
    let confidence: Double
    let region: Region
}
