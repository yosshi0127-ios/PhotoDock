//
//  SpyPixelSourceService.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出しを記録する `PixelSourceService`。
/// 渡された mode を残すのは、「ダウンロードしてよい」判断が経路を通っていることを検証するため
/// （通らなくても取れる写真だけが診断されて正常に見えてしまう）。
actor SpyPixelSourceService: PixelSourceService {
    private let stubbedOutcome: PixelSourceOutcome

    private(set) var requestedIDs: [String] = []
    private(set) var requestedModes: [PixelFetchMode] = []
    private(set) var requestedThumbnailIDs: [String] = []

    init(outcome: PixelSourceOutcome) {
        self.stubbedOutcome = outcome
    }

    func fetchImageData(for id: String, mode: PixelFetchMode) async -> PixelSourceOutcome {
        requestedIDs.append(id)
        requestedModes.append(mode)
        return stubbedOutcome
    }

    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data? {
        requestedThumbnailIDs.append(id)
        guard case let .data(data) = stubbedOutcome else { return nil }
        return data
    }
}
