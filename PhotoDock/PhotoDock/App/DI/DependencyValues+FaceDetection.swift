//
//  DependencyValues+FaceDetection.swift
//  PhotoDock
//

import Dependencies

// 画像から顔の位置と向きを検出する。写り込みらしい顔を所見にするための入力。
// preview は Vision を呼ばず、写り込みらしい顔を1つ固定で返す（枠と所見リストの見た目が成立する）。
// live はシミュレータでは検出ゼロで続行する（Vision の顔検出が code 9 で動かないため）。
private enum FaceDetectionServiceKey: DependencyKey {
    static let liveValue: any FaceDetectionService = VisionFaceDetectionService()
    static let previewValue: any FaceDetectionService = StubFaceDetectionService()
    static let testValue: any FaceDetectionService = UnimplementedFaceDetectionService()
}

extension DependencyValues {
    var faceDetection: any FaceDetectionService {
        get { self[FaceDetectionServiceKey.self] }
        set { self[FaceDetectionServiceKey.self] = newValue }
    }
}
