//
//  SpyContinuedProcessingService.swift
//  PhotoDockTests
//

@testable import PhotoDock

/// 申告・進捗・終了を記録する `ContinuedProcessingService`。
/// 期限切れ（OS の打ち切り）を再現できるようにしてある — 打ち切られたら残りの診断が止まることを固定するため
actor SpyContinuedProcessingService: ContinuedProcessingService {
    /// false なら「申告できない環境」として nil を返す（Preview の Stub と同じ経路）
    private let isSupported: Bool
    /// この回数目の report を受けた直後に onExpire を呼ぶ（ユーザーが Live Activity で中止した状況）
    private let expiresAfterReports: Int?

    private(set) var begun: [ContinuedWork] = []
    private(set) var reports: [(completedUnits: Int, subtitle: String)] = []
    private(set) var ended: [Bool] = []
    private var onExpire: (@Sendable () -> Void)?

    init(isSupported: Bool = true, expiresAfterReports: Int? = nil) {
        self.isSupported = isSupported
        self.expiresAfterReports = expiresAfterReports
    }

    func begin(_ work: ContinuedWork, onExpire: @escaping @Sendable () -> Void) -> ContinuedProcessingSession? {
        guard isSupported else { return nil }
        begun.append(work)
        self.onExpire = onExpire
        return ContinuedProcessingSession(
            report: { completed, subtitle in await self.record(completed, subtitle: subtitle) },
            end: { success in await self.recordEnd(success) }
        )
    }

    private func record(_ completedUnits: Int, subtitle: String) {
        reports.append((completedUnits, subtitle))
        if reports.count == expiresAfterReports {
            onExpire?()
        }
    }

    private func recordEnd(_ success: Bool) {
        ended.append(success)
    }
}
