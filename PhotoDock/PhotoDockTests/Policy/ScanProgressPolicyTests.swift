//
//  ScanProgressPolicyTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

@Suite("ScanProgressPolicy")
struct ScanProgressPolicyTests {
    private let sut = ScanProgressPolicy(minimumSamples: 10, minimumElapsedSeconds: 3)

    @Test("今回診断した速さを、残りの枚数に掛ける")
    func estimatesFromThroughput() {
        // 100 枚に 20 秒 = 1枚 0.2 秒。残り 300 枚なら 60 秒
        #expect(sut.remainingSeconds(diagnosedNow: 100, remaining: 300, elapsedSeconds: 20) == 60)
    }

    /// 数枚では、文字の多い1枚に引きずられる
    @Test("診断した枚数が少ないうちは見積もらない")
    func noEstimateWithFewSamples() {
        #expect(sut.remainingSeconds(diagnosedNow: 9, remaining: 300, elapsedSeconds: 20) == nil)
        #expect(sut.remainingSeconds(diagnosedNow: 10, remaining: 300, elapsedSeconds: 20) != nil)
    }

    @Test("始めた直後は見積もらない")
    func noEstimateRightAfterStart() {
        #expect(sut.remainingSeconds(diagnosedNow: 50, remaining: 300, elapsedSeconds: 2.9) == nil)
        #expect(sut.remainingSeconds(diagnosedNow: 50, remaining: 300, elapsedSeconds: 3) != nil)
    }

    @Test("残りが無ければ出さない")
    func noEstimateWhenNothingRemains() {
        #expect(sut.remainingSeconds(diagnosedNow: 100, remaining: 0, elapsedSeconds: 20) == nil)
    }

    /// 記録の再利用だけで進んだあいだは、今回診断した枚数が 0 のまま。
    /// 0 で割って無限大や非数を返さないこと
    @Test("今回まだ1枚も診断していなければ出さない")
    func noEstimateBeforeAnyDiagnosis() {
        #expect(sut.remainingSeconds(diagnosedNow: 0, remaining: 100, elapsedSeconds: 10) == nil)
    }
}
