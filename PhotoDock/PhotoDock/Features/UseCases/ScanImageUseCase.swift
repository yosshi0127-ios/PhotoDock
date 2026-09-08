//
//  ScanImageUseCase.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Dependencies
import Foundation

/// 画像データ1枚を診断する。ライブラリ経路（ScanPhotoUseCase）もここに委譲するので、
/// 2経路で ocr → Policy のパイプラインが必ず一致する。
struct ScanImageUseCase: Sendable {
    @Dependency(\.ocr) private var ocr
    
    private let policy = FindingPolicy()
    
    func callAsFunction(imageData: Data, quality: ScanQuality) async -> [Finding] {
        let texts = await ocr.recognizeText(in: imageData, maxPixelSize: quality.maxPixelSize)
        return policy.findings(in: texts)
    }
}

