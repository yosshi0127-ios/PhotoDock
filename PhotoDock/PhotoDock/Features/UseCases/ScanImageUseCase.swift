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

    func callAsFunction(imageData: Data, quality: ScanQuality) async -> ImageScanOutcome {
        // 同じ maxPixelSize で復号させる。縮小率が違うと2つの座標系がずれて枠が合わなくなる
        async let recognition = ocr.recognizeText(in: imageData, maxPixelSize: quality.maxPixelSize)
        async let faces = faceDetection.detectFaces(in: imageData, maxPixelSize: quality.maxPixelSize)

        let (recognized, detectedFaces) = await (recognition, faces)

        // 文字を読めなかった写真は、顔が見つかっていても「診断できた」にしない。
        // 所見ゼロや顔だけの結果を記録すると、文字を見ていない写真が診断済みとして残る
        guard case let .recognized(texts) = recognized else { return .failed }

        return .scanned(policy.findings(in: texts, faces: detectedFaces))
    }
}
