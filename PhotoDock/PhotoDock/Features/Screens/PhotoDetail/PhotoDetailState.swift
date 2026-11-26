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

    /// 所見の枠を重ねる下地。読み込み中と、読み込めなかったときは nil
    private(set) var image: UIImage?

    /// 写真を読み込んでいる途中か。終わっても image が nil なら、表示できなかった
    private(set) var isLoadingImage = true

    /// 種類ごとにまとめた所見。写真の読み込みを待たずに出す
    private(set) var findings: [ReportPhotoFinding] = []

    // 依存は UseCase 経由のみ
    private let loadThumbnail = LoadThumbnailUseCase()
    private let reportPolicy = ScanReportPolicy()

    private var didShow = false

    /// 記録をそのまま見せる。
    /// 表示は縮小版で足りる — Region は正規化座標なので、比率が同じなら枠は合う
    func show(record: ScanRecord) async {
        guard !didShow else { return }   // 再表示のたびに読み直さない
        didShow = true

        findings = reportPolicy.findings(in: record)
        image = await loadThumbnail(assetID: record.assetID, maxPixelSize: 1_200).flatMap(UIImage.init(data:))
        isLoadingImage = false
    }
}
