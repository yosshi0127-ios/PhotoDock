//
//  ScanPhotoUseCase.swift
//  PhotoDock
//

import Dependencies

/// ライブラリの1枚を診断する。取得だけを担い、診断は ScanImageUseCase に委譲する
/// （ライブラリ経路と画像データ経路で ocr → Policy のパイプラインが必ず一致する）。
struct ScanPhotoUseCase: Sendable {
    @Dependency(\.pixelSource) private var pixelSource

    private let scanImage = ScanImageUseCase()

    /// mode は「ダウンロードしてよいか」。ユーザーの設定と回線から呼び出し側が決めて渡す
    func callAsFunction(assetID: String, quality: ScanQuality, mode: PixelFetchMode) async -> PhotoScanOutcome {
        switch await pixelSource.fetchImageData(for: assetID, mode: mode) {
        case .notAvailableLocally: .notAvailableLocally
        case .unavailableInCloud: .unavailableInCloud
        case .missing: .missing
        case let .data(data): .scanned(await scanImage(imageData: data, quality: quality))
        }
    }
}
