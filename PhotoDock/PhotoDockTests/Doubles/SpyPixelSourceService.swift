//
//  SpyPixelSourceService.swift
//  PhotoDockTests
//

@testable import PhotoDock

/// 呼び出しを記録する `PixelSourceService`。
actor SpyPixelSourceService: PixelSourceService {
    private let stubbedOutcome: PixelSourceOutcome

    private(set) var requestedIDs: [String] = []

    init(outcome: PixelSourceOutcome) {
        self.stubbedOutcome = outcome
    }

    func fetchImageData(for id: String) async -> PixelSourceOutcome {
        requestedIDs.append(id)
        return stubbedOutcome
    }
}
