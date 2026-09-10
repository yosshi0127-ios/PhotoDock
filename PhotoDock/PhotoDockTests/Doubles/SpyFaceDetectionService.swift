//
//  SpyFaceDetectionService.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出しを記録する `FaceDetectionService`。
actor SpyFaceDetectionService: FaceDetectionService {
    private let stubbedFaces: [DetectedFace]

    private(set) var callCount = 0
    private(set) var receivedMaxPixelSizes: [Int] = []

    init(faces: [DetectedFace] = []) {
        self.stubbedFaces = faces
    }

    func detectFaces(in data: Data, maxPixelSize: Int) async -> [DetectedFace] {
        callCount += 1
        receivedMaxPixelSizes.append(maxPixelSize)
        return stubbedFaces
    }
}
