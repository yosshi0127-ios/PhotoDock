//
//  CloudDownloadPolicyTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

/// iCloud の写真を取り寄せる前に見せる見積もり
@Suite("CloudDownloadPolicy")
struct CloudDownloadPolicyTests {
    private let sut = CloudDownloadPolicy(megabytesPerPhoto: 2, secondsPerPhoto: 0.5)

    @Test("枚数に、1枚あたりの通信量と時間を掛ける")
    func scalesWithCount() {
        #expect(sut.estimate(photoCount: 100) == CloudDownloadEstimate(photoCount: 100, megabytes: 200, seconds: 50))
    }

    @Test("0枚・負の枚数は、0 として見積もる")
    func clampsToZero() {
        #expect(sut.estimate(photoCount: 0) == CloudDownloadEstimate(photoCount: 0, megabytes: 0, seconds: 0))
        #expect(sut.estimate(photoCount: -3) == CloudDownloadEstimate(photoCount: 0, megabytes: 0, seconds: 0))
    }

    /// 実機（2,169 枚が iCloud のみ）で見せる数字。実測値を変えたら、ここも見直す
    @Test("実測値での見積もり: 2,169 枚で約 4.1GB・約 30 分")
    func realWorldFigures() {
        let estimate = CloudDownloadPolicy().estimate(photoCount: 2_169)

        #expect(estimate.sizeText == "約 4.1GB")
        #expect(estimate.durationText == "約 30 分")
    }

    @Test("1GB 未満は MB で、1分未満は「1 分以内」と書く")
    func smallFigures() {
        let estimate = CloudDownloadPolicy().estimate(photoCount: 20)

        #expect(estimate.sizeText == "約 37MB")
        #expect(estimate.durationText == "1 分以内")
    }
}
