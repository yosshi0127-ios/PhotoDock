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

        /// 実行したあとに、対応として残す種類
        var disposition: PhotoDisposition.Action {
            switch self {
            case .hide: .hidden
            case .delete: .deleted
            }
        }
    }

    @Dependency(\.photoActions) private var photoActions
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()

    /// takenAt は写真を撮った日。あとで対応済みの一覧に出すために控える（実行したあとは、もう読めない）
    func callAsFunction(_ method: Method, record: ScanRecord, takenAt: Date? = nil) async -> PhotoActionOutcome {
        let outcome = switch method {
        case .hide: await photoActions.hide(assetIDs: [record.assetID])
        case .delete: await photoActions.delete(assetIDs: [record.assetID])
        }
        guard outcome == .done else { return outcome }

        try? await photoDispositions.save(
            reportPolicy.disposition(method.disposition, for: record, takenAt: takenAt, decidedAt: .now)
        )
        return .done
    }
}
