//
//  ScanProgressPolicyTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

@Suite("ScanProgressPolicy")
struct ScanProgressPolicyTests {
    private let sut = ScanProgressPolicy(minimumSamples: 10, minimumElapsedSeconds: 3, quickSecondsPerPhoto: 0.01)

    private func estimate(diagnosedNow: Int, toDiagnose: Int, quick: Int = 0, elapsed: Double) -> Double? {
        sut.remainingSeconds(
            diagnosedNow: diagnosedNow, remainingToDiagnose: toDiagnose, remainingQuick: quick, elapsedSeconds: elapsed
        )
    }

    @Test("実際に診断した速さを、これから診断する枚数に掛ける")
    func estimatesFromThroughput() {
        // 100 枚に 20 秒 = 1枚 0.2 秒。残り 300 枚なら 60 秒
        #expect(estimate(diagnosedNow: 100, toDiagnose: 300, elapsed: 20) == 60)
    }

    /// 実機で、端末の写真を診断し終えたあとに iCloud の 2,169枚が 25秒かかった
    @Test("すぐ終わる写真は、決まった秒数で足す")
    func addsFixedTimeForQuickPhotos() {
        // 診断のぶん 60 秒 + 2,000 枚 × 0.01 秒
        #expect(estimate(diagnosedNow: 100, toDiagnose: 300, quick: 2_000, elapsed: 20) == 80)
    }

    @Test("診断する写真が残っていなければ、すぐ終わる写真のぶんだけを出す（速さを測る前でも）")
    func onlyQuickPhotosRemain() {
        #expect(estimate(diagnosedNow: 0, toDiagnose: 0, quick: 2_000, elapsed: 0.5) == 20)
    }

    /// 数枚では、文字の多い1枚に引きずられる
    @Test("診断した枚数が少ないうちは見積もらない")
    func noEstimateWithFewSamples() {
        #expect(estimate(diagnosedNow: 9, toDiagnose: 300, elapsed: 20) == nil)
        #expect(estimate(diagnosedNow: 10, toDiagnose: 300, elapsed: 20) != nil)
    }

    @Test("始めた直後は見積もらない")
    func noEstimateRightAfterStart() {
        #expect(estimate(diagnosedNow: 50, toDiagnose: 300, elapsed: 2.9) == nil)
        #expect(estimate(diagnosedNow: 50, toDiagnose: 300, elapsed: 3) != nil)
    }

    @Test("残りが無ければ出さない")
    func noEstimateWhenNothingRemains() {
        #expect(estimate(diagnosedNow: 100, toDiagnose: 0, elapsed: 20) == nil)
        // 見込みより多く診断した（負になる）ときも同じ
        #expect(estimate(diagnosedNow: 100, toDiagnose: -5, quick: 0, elapsed: 20) == nil)
    }

    /// 記録の再利用だけで進んだあいだは、実際に診断した枚数が 0 のまま。
    /// 0 で割って無限大や非数を返さないこと
    @Test("まだ1枚も診断していなければ出さない")
    func noEstimateBeforeAnyDiagnosis() {
        #expect(estimate(diagnosedNow: 0, toDiagnose: 100, elapsed: 10) == nil)
    }

    @Test("画像を読むところまで進んだ結果だけを、時間のかかる結果として数える")
    func takesTimeOnlyWhenImageWasRead() {
        #expect(sut.takesTime(.scanned([])))
        #expect(sut.takesTime(.failed))
        #expect(sut.takesTime(.unavailableInCloud))
        // 端末に無い・見つからない写真は、画像を読む前に分かる
        #expect(!sut.takesTime(.notAvailableLocally))
        #expect(!sut.takesTime(.missing))
    }
}
