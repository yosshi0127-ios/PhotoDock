//
//  RemovePhotoUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 写真を非表示にする・削除する。順序の知識だけを持つ:
/// ライブラリを書き換える（OS が確認を出す）→ 実行されたときだけ、対応として保存する。
///
/// 対応の保存に失敗しても、結果は「実行された」のまま返す。写真はもう動いていて、取り消せない。
/// その場合、写真は結果票から消えるだけで「対応済み」には数えられない（数が1つ合わないが、嘘は出ない）
struct RemovePhotoUseCase: Sendable {
    /// ライブラリから見えなくする方法
    enum Method: Sendable, Equatable {
        case hide
        case delete
    }

    @Dependency(\.photoActions) private var photoActions
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()

    func callAsFunction(_ method: Method, record: ScanRecord) async -> PhotoActionOutcome {
        let outcome = switch method {
        case .hide: await photoActions.hide(assetID: record.assetID)
        case .delete: await photoActions.delete(assetID: record.assetID)
        }
        guard outcome == .done else { return outcome }

        let action: PhotoDisposition.Action = method == .hide ? .hidden : .deleted
        try? await photoDispositions.save(reportPolicy.disposition(action, for: record, decidedAt: .now))
        return .done
    }
}
