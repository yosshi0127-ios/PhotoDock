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
    private static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
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
