//
//  ReopenPhotoUseCase.swift
//  PhotoDock
//

import Dependencies

/// 「未対応に戻す」。「問題なし」の印を消す。保存先に書けなければ throw する
struct ReopenPhotoUseCase: Sendable {
    @Dependency(\.photoDispositions) private var photoDispositions

    func callAsFunction(assetID: String) async throws {
        try await photoDispositions.remove(assetID: assetID)
    }
}
