//
//  PhotoDetailState.swift
//  PhotoDock
//

import Observation
import UIKit

/// 写真詳細の状態。
/// **記録を表示するだけで診断しない** — 一覧と詳細が同じ記録を見るので食い違わない。
@MainActor
@Observable
final class PhotoDetailState {

    enum Phase: Equatable {
        case empty
        case checking
        case checked([StoredFinding])
    }

    private(set) var phase: Phase = .empty

    /// 所見の枠を重ねる下地。UIImage は Equatable にならないので Phase には入れない
    private(set) var image: UIImage?

    // 依存は UseCase 経由のみ
    private let loadThumbnail = LoadThumbnailUseCase()

    /// 記録をそのまま見せる。
    /// 表示は縮小版で足りる — Region は正規化座標なので、比率が同じなら枠は合う
    func show(record: ScanRecord) async {
        guard case .empty = phase else { return }

        phase = .checking
        image = await loadThumbnail(assetID: record.assetID, maxPixelSize: 1_200).flatMap(UIImage.init(data:))
        phase = .checked(record.findings)
    }
}
