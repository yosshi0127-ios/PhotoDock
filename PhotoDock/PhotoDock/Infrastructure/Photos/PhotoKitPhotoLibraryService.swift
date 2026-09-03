//
//  PhotoKitPhotoLibraryService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

import Foundation
import Photos

struct PhotoKitPhotoLibraryService: PhotoLibraryService {
    /// PhotoKit の許可状態をこのアプリの語彙に翻訳する。
    /// `.authorized`（全許可）は limited と対比させたいので full と呼ぶ。
    /// 未知のケースは「読めない」側に倒す（読めると誤解すると偽の ✅ を出してしまう）。
    private static func access(from status: PHAuthorizationStatus) -> PhotoLibraryAccess {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted:    .restricted
        case .denied:        .denied
        case .authorized:    .full
        case .limited:       .limited
        @unknown default:    .denied
        }
    }

    func currentAccess() async -> PhotoLibraryAccess {
        Self.access(from: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoLibraryAccess {
        Self.access(from: await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    func fetchAllAssetMetadata() async -> [AssetMetadata] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // `.image` で動画を除外する（契約）。返るのは遅延カーソルなので、
        // この時点では画像データもメタデータも読まれていない（だから count が安い）。
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var metadata: [AssetMetadata] = []
        metadata.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            metadata.append(
                AssetMetadata(
                    id: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    modificationDate: asset.modificationDate,
                    coordinate: asset.location.map {
                        GeoCoordinate(latitude: $0.coordinate.latitude,
                                      longitude: $0.coordinate.longitude)
                    },
                    isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
                )
            )
        }

        return metadata
    }
}
