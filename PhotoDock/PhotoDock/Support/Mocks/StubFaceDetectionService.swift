//
//  StubFaceDetectionService.swift
//  PhotoDock
//

import Foundation

/// Preview 用の偽の顔検出。Vision には触らず、写り込みらしい顔を1つ固定で返す
/// （右上の端・小さい・横向き）。所見リストと枠の見た目を Preview で確認するための値で、
/// 画像の中身は見ていない。
struct StubFaceDetectionService: FaceDetectionService {
    func detectFaces(in data: Data, maxPixelSize: Int) async -> [DetectedFace] {
        [
            DetectedFace(
                region: Region(x: 0.86, y: 0.08, width: 0.06, height: 0.08),
                yaw: 0.9
            )
        ]
    }
}
