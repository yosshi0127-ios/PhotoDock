//
//  DismissPhotosUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 何枚かの写真を、まとめて「問題なし」にする。写真ライブラリには触らない（アプリの中の印だけ）。
/// 途中で保存に失敗したら、そこで止めて throw する（それまでの分は保存されている。もう一度押せば続きから付く）
struct DismissPhotosUseCase: Sendable {
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()

    func callAsFunction(photos: [ReportItemPhoto]) async throws {
        let decidedAt = Date.now
        for photo in photos {
            try await photoDispositions.save(
                reportPolicy.disposition(.dismissed, for: photo.record, takenAt: photo.takenAt, decidedAt: decidedAt)
            )
        }
    }
}
