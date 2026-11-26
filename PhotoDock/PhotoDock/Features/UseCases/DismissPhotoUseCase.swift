//
//  DismissPhotoUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 「問題なしにする」。その写真の所見を、対応済みとして保存する。
/// 写真ライブラリには触らない（アプリの中の印だけ）。保存できなければ throw する
struct DismissPhotoUseCase: Sendable {
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()

    func callAsFunction(record: ScanRecord, takenAt: Date? = nil) async throws {
        try await photoDispositions.save(
            reportPolicy.disposition(.dismissed, for: record, takenAt: takenAt, decidedAt: .now)
        )
    }
}
