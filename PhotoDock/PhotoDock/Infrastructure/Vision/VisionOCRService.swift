//
//  VisionOCRService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Foundation
import Vision

struct VisionOCRService: OCRService {
    
    @concurrent
    func recognizeText(in data: Data, maxPixelSize: Int) async -> [RecognizedText] {
        guard let cgImage = Self.decode(data, maxPixelSize: maxPixelSize) else { return [] }

        // 前段: 文字らしい矩形が1つも無ければ OCR を走らせない。
        // 大半の写真には文字が無く、OCR は「探して何も見つけない」だけで 270ms 使う。
        // 矩形検出は 15ms（OCR の 6%）で、162枚の実測で本物の文字は1枚も落とさなかった
        // （唯一「見逃し」に見えた1枚は OCR が模様を「■」確度0.30 と誤認したもので、
        // Policy の確度閾値 0.5 で捨てられる行だった）。全体で 3.1 倍速。
        guard Self.containsTextRectangles(in: cgImage) else { return [] }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = false
        
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            // 1枚の失敗で数万枚のスキャンを止めない
            return []
        }
        
        return (request.results ?? []).compactMap(Self.recognizedText(from:))
    }
    
    /// 復号と縮小を同時に行う。EXIF の向きも適用するので、以降は回転後の画像として扱える。
    /// internal なのはテストが前段（containsTextRectangles）に同じ手順で画像を渡すため
    static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    /// 読まずに「文字らしい矩形があるか」だけを見る。
    /// 言語非依存なので、.fast のように日本語で困ることがない。
    /// 判定に失敗したら true（OCR に回す）。見逃す方向には倒さない
    static func containsTextRectangles(in cgImage: CGImage) -> Bool {
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return true
        }

        return (request.results ?? []).isEmpty == false
    }
    
    
    /// Vision の boundingBox（左下原点）を Region（左上原点）へ変換する。
    private static func recognizedText(from observation: VNRecognizedTextObservation) -> RecognizedText? {
        guard let candidate = observation.topCandidates(1).first else { return nil }
        
        let box = observation.boundingBox
        
        return RecognizedText(
            text: candidate.string,
            confidence: Double(candidate.confidence),
            region: Region(
                x: box.origin.x,
                y: 1 - (box.origin.y + box.height),
                width: box.width,
                height: box.height
            )
        )
    }
    
    
}
