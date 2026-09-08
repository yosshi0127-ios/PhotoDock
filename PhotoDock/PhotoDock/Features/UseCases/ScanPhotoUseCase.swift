//
//  ScanPhotoUseCase.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Dependencies

struct ScanPhotoUseCase: Sendable {
    @Dependency(\.pixelSource) private var pixelSource

    private let scanImage = ScanImageUseCase()
    
    func callAsFunction(assetID: String, quality: ScanQuality) async -> PhotoScanOutcome {
        switch await pixelSource.fetchImageData(for: assetID) {
        case .notAvailableLocally: .notAvailableLocally
        case .missing: .missing
        case let .data(data): .scanned(await scanImage(imageData: data, quality: quality))
        }
    }
}
