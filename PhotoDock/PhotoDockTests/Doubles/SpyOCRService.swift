//
//  SpyOCRService.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出しを記録する `OCRService`。
///
/// 渡された `maxPixelSize` を残すのは、品質ノブが経路を通っていることを検証するため
/// （無視する実装に書き換わっても「遅いだけ／精度が低いだけ」で正常に見えてしまう）。
actor SpyOCRService: OCRService {
    private let stubbedOutcome: OCROutcome

    private(set) var callCount = 0
    private(set) var receivedMaxPixelSizes: [Int] = []

    init(texts: [RecognizedText] = []) {
        self.stubbedOutcome = .recognized(texts)
    }

    /// 読めなかった場合（`.failed`）を返させたいとき
    init(outcome: OCROutcome) {
        self.stubbedOutcome = outcome
    }

    func recognizeText(in data: Data, maxPixelSize: Int) async -> OCROutcome {
        callCount += 1
        receivedMaxPixelSizes.append(maxPixelSize)
        return stubbedOutcome
    }
}
