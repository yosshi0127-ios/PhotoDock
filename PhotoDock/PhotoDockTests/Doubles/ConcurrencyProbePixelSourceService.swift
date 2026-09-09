//
//  ConcurrencyProbePixelSourceService.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 同時に何本走っていたかを記録する `PixelSourceService`。
///
/// 並列数の制御は「動いているが遅い」形で壊れる（全部直列になる／制限を超えて走る）。
/// どちらも結果は正しく出てしまうので、実行の重なり方を測らないと検出できない。
actor ConcurrencyProbePixelSourceService: PixelSourceService {
    private let delay: Duration
    private let stubbedOutcome: PixelSourceOutcome

    private var running = 0
    private(set) var maxConcurrent = 0
    private(set) var callCount = 0
    /// キャンセル済みの状態で始まった呼び出し。UseCase が仕事を積み続けると増える
    private(set) var startedWhileCancelled = 0

    init(delay: Duration = .milliseconds(10), outcome: PixelSourceOutcome = .data(Data("image".utf8))) {
        self.delay = delay
        self.stubbedOutcome = outcome
    }

    func fetchImageData(for id: String) async -> PixelSourceOutcome {
        if Task.isCancelled { startedWhileCancelled += 1 }

        running += 1
        maxConcurrent = max(maxConcurrent, running)
        callCount += 1

        // Task.sleep はキャンセルで即座に返るため、それだと「キャンセル後も走り続ける」
        // 状態と「ちゃんと止まった」状態を区別できない。ここでは意図的に待ち切る。
        // await するので actor は解放され、重なりは measurable なまま
        let deadline = ContinuousClock.now.advanced(by: delay)
        while ContinuousClock.now < deadline {
            await Task.yield()
        }

        running -= 1
        return stubbedOutcome
    }
}
