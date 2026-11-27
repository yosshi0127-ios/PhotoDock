//
//  RemovePhotosUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 何枚かの写真を、まとめて非表示にする・削除する。順序は1枚のとき（`RemovePhotoUseCase`）と同じ:
/// ライブラリを書き換える（OS の確認は、まとめて1回）→ 実行されたときだけ、1枚ずつ対応として保存する。
///
/// やめた・できなかったときは、1枚も保存しない。
/// 対応の保存に失敗した写真があっても、結果は「実行された」のまま返す（写真はもう動いていて、取り消せない）
struct RemovePhotosUseCase: Sendable {
    @Dependency(\.photoActions) private var photoActions
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()

    func callAsFunction(_ method: RemovePhotoUseCase.Method, photos: [ReportItemPhoto]) async -> PhotoActionOutcome {
        guard !photos.isEmpty else { return .notFound }

        let assetIDs = photos.map(\.id)
        let outcome = switch method {
        case .hide: await photoActions.hide(assetIDs: assetIDs)
        case .delete: await photoActions.delete(assetIDs: assetIDs)
        }
        guard outcome == .done else { return outcome }

        let decidedAt = Date.now
        for photo in photos {
            try? await photoDispositions.save(
                reportPolicy.disposition(method.disposition, for: photo.record, takenAt: photo.takenAt, decidedAt: decidedAt)
            )
        }
        return .done
    }
}
