//
//  PhotoDetailState.swift
//  PhotoDock
//

import Observation
import UIKit

/// 写真詳細の状態。
/// 一覧から開いたときは**記録を表示するだけで診断しない** — 一覧と詳細が同じ記録を見るので食い違わない。
/// PhotosPicker で選んだ1枚には記録が無いので、その経路だけ精密で診断する。
@MainActor
@Observable
final class PhotoDetailState {

    enum Phase: Equatable {
        case empty
        case checking
        case checked([StoredFinding])
        /// 読み込めなかった（選択の読み込み失敗・画像として壊れている）
        case undecodable
    }

    private(set) var phase: Phase = .empty

    /// 所見の枠を重ねる下地。UIImage は Equatable にならないので Phase には入れない
    private(set) var image: UIImage?

    // 依存は UseCase 経由のみ
    private let scanImage = ScanImageUseCase()
    private let loadThumbnail = LoadThumbnailUseCase()

    /// 一覧からの経路。記録をそのまま見せる。
    /// 表示は縮小版で足りる — Region は正規化座標なので、比率が同じなら枠は合う
    func show(record: ScanRecord) async {
        guard case .empty = phase else { return }

        phase = .checking
        image = await loadThumbnail(assetID: record.assetID, maxPixelSize: 1_200).flatMap(UIImage.init(data:))
        phase = .checked(record.findings)
    }

    /// PhotosPicker からの経路。記録が無いので診断する。
    /// imageData が nil なのは、PhotosPicker からの読み込みが失敗した場合
    func check(imageData: Data?) async {
        guard let imageData, let decoded = UIImage(data: imageData) else {
            image = nil
            phase = .undecodable
            return
        }

        image = decoded
        phase = .checking
        let findings = await scanImage(imageData: imageData, quality: .precise)
        // 表示は記録から開いたときと同じ形（本文なし）に揃える
        phase = .checked(findings.map(StoredFinding.init))
    }
}
