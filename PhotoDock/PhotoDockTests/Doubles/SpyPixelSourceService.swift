//
//  SpyPixelSourceService.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出しを記録する `PixelSourceService`。
actor SpyPixelSourceService: PixelSourceService {
    private let stubbedOutcome: PixelSourceOutcome

    private(set) var requestedIDs: [String] = []
    private(set) var requestedThumbnailIDs: [String] = []

    init(outcome: PixelSourceOutcome) {
        self.stubbedOutcome = outcome
    }

    func fetchImageData(for id: String) async -> PixelSourceOutcome {
        requestedIDs.append(id)
        return stubbedOutcome
    }

    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data? {
        requestedThumbnailIDs.append(id)
        guard case let .data(data) = stubbedOutcome else { return nil }
        return data
    }
}
