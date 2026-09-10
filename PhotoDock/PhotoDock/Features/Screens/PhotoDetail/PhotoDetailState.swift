//
//  PhotoDetailState.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/09.
//

import Observation
import UIKit

@MainActor
@Observable
final class PhotoDetailState {
 
    enum Phase: Equatable {
        case empty
        case checking
        case checked([Finding])
        /// 読み込めなかった（選択の読み込み失敗・画像として壊れている）
        case undecodable
        /// iCloud にしかなくて取れなかった。通信しない契約なのでここで止まる
        case notAvailableLocally
    }

    private(set) var phase: Phase = .empty

    private(set) var image: UIImage?

    private let scanImage = ScanImageUseCase()
    private let scanPhoto = ScanPhotoUseCase()
    private let loadThumbnail = LoadThumbnailUseCase()

    /// imageData が nil なのは、PhotosPicker からの読み込みが失敗した場合
    func check(imageData: Data?) async {
        guard let imageData, let decoded = UIImage(data: imageData) else {
            image = nil
            phase = .undecodable
            return
        }

        image = decoded
        phase = .checking
        phase = .checked(await scanImage(imageData: imageData, quality: .precise))
    }

    /// ライブラリの1枚を開く経路（一覧からの遷移）。
    /// 表示は縮小版で足りる — Region は正規化座標なので、比率が同じなら枠は合う。
    /// 診断のほうは原寸から精密で行う（品質を表示都合に引きずられないため）。
    func check(assetID: String) async {
        guard case .empty = phase else { return }

        phase = .checking

        async let thumbnail = loadThumbnail(assetID: assetID, maxPixelSize: 1_200)
        async let outcome = scanPhoto(assetID: assetID, quality: .precise)

        image = await thumbnail.flatMap(UIImage.init(data:))

        switch await outcome {
        case let .scanned(findings): phase = .checked(findings)
        case .notAvailableLocally: phase = .notAvailableLocally
        case .missing: phase = .undecodable
        }
    }
}
