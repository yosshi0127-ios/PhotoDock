//
//  LoadThumbnailUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 一覧に並べる縮小画像を1枚取る。
/// 中身は pixelSource を呼ぶだけだが、生の依存を持てるのは UseCase だけなので
/// ここを通す（セルの State が直接サービスを触らないようにする）。
struct LoadThumbnailUseCase: Sendable {
    @Dependency(\.pixelSource) private var pixelSource

    func callAsFunction(assetID: String, maxPixelSize: Int) async -> Data? {
        await pixelSource.fetchThumbnail(for: assetID, maxPixelSize: maxPixelSize)
    }
}
