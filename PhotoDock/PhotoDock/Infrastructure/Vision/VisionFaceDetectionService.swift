//
//  VisionFaceDetectionService.swift
//  PhotoDock
//

import Foundation
import Vision

struct VisionFaceDetectionService: FaceDetectionService {

    @concurrent
    func detectFaces(in data: Data, maxPixelSize: Int) async -> [DetectedFace] {
        guard let cgImage = VisionImageDecoder.decode(data, maxPixelSize: maxPixelSize) else { return [] }

        let request = VNDetectFaceRectanglesRequest()

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            // シミュレータでは code 9（Could not create inference context）で必ずここに来る。
            // 契約どおり「検出ゼロで続行」。実機でも1枚の失敗でスキャンを止めない
            return []
        }

        return (request.results ?? []).map(Self.detectedFace(from:))
    }

    /// Vision の boundingBox（左下原点）を Region（左上原点）へ。OCR と同じ変換
    private static func detectedFace(from observation: VNFaceObservation) -> DetectedFace {
        let box = observation.boundingBox

        return DetectedFace(
            region: Region(
                x: box.origin.x,
                y: 1 - (box.origin.y + box.height),
                width: box.width,
                height: box.height
            ),
            yaw: observation.yaw?.doubleValue
        )
    }
}
