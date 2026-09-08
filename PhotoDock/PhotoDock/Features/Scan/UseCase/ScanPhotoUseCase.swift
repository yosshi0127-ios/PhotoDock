//
//  ScanPhotoUseCase.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Dependencies

struct ScanPhotoUseCase: Sendable {
    @Dependency(\.pixelSource) private var pixelSource
    @Dependency(\.ocr) private var ocr

    private let policy = FindingPolicy()

    func callAsFunction(assetID: String, quality: ScanQuality) async -> PhotoScanOutcome {
        switch await pixelSource.fetchImageData(for: assetID) {
        case .notAvailableLocally:
            return .notAvailableLocally
        case .missing:
            return .missing
        case let .data(data):
            let texts = await ocr.recognizeText(in: data, maxPixelSize: quality.maxPixelSize)
            return .scanned(policy.findings(in: texts))
        }
    }
}
