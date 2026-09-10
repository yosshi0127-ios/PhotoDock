//
//  ScanImageUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 画像データ1枚を診断する。ライブラリ経路（ScanPhotoUseCase）もここに委譲するので、
/// 2経路で「検出 → Policy」のパイプラインが必ず一致する。
///
/// 検出器は OCR と顔検出の2本。同じ画像を独立に見るので並行に走らせ、
/// 結果をまとめて Policy に渡す（判断は Policy、段取りだけがここ）。
struct ScanImageUseCase: Sendable {
    @Dependency(\.ocr) private var ocr
    @Dependency(\.faceDetection) private var faceDetection

    private let policy = FindingPolicy()

    func callAsFunction(imageData: Data, quality: ScanQuality) async -> [Finding] {
        // 同じ maxPixelSize で復号させる。縮小率が違うと2つの座標系がずれて枠が合わなくなる
        async let texts = ocr.recognizeText(in: imageData, maxPixelSize: quality.maxPixelSize)
        async let faces = faceDetection.detectFaces(in: imageData, maxPixelSize: quality.maxPixelSize)

        return policy.findings(in: await texts, faces: await faces)
    }
}
