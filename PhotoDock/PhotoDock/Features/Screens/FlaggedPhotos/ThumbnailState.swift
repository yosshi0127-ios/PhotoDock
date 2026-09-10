//
//  ThumbnailState.swift
//  PhotoDock
//

import Observation
import UIKit

/// グリッドのセル1つ分の状態。表示されたセルだけが読み込むように、
/// State をセルごとに持たせている（一覧を開いた瞬間に全件読むとメモリが持たない）。
@MainActor
@Observable
final class ThumbnailState {

    private(set) var image: UIImage?

    // 依存は UseCase 経由のみ
    private let loadThumbnail = LoadThumbnailUseCase()

    func load(assetID: String, maxPixelSize: Int) async {
        guard image == nil else { return }   // 再表示のたびに読み直さない

        guard let data = await loadThumbnail(assetID: assetID, maxPixelSize: maxPixelSize) else {
            return
        }
        image = UIImage(data: data)
    }
}
