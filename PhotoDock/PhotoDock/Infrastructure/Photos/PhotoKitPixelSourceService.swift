//
//  PhotoKitPixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Photos
import UIKit

struct PhotoKitPixelSourceService: PixelSourceService {
    
    /// asset ID で1枚引き、元ファイルのバイト列を返す。取れなかった理由は Outcome で区別する。
    @concurrent   // 重い I/O。付けないと呼び出し元のメインスレッドを塞ぐ
    func fetchImageData(for id: String) async -> PixelSourceOutcome {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return .missing
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false   // 契約: ダウンロードしない
            
        return await withCheckedContinuation { continuation in
            // requestImageDataAndOrientation は結果を1回だけ返す
            // （requestImage は「低品質 → 高品質」で複数回来るので continuation には使えない）
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let data {
                    continuation.resume(returning: .data(data))
                } else if info?[PHImageResultIsInCloudKey] as? Bool == true {
                    continuation.resume(returning: .notAvailableLocally)
                } else {
                    continuation.resume(returning: .missing)
                }
            }
        }
    }

    /// 一覧用の縮小画像。JPEG にするのはグリッドに数百枚並べるため
    /// （PNG は非圧縮に近く、サムネイルでもメモリを食う）。
    @concurrent
    func fetchThumbnail(for id: String, maxPixelSize: Int) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false   // 契約: ダウンロードしない
        options.resizeMode = .fast
        // 既定の .opportunistic は「低品質 → 高品質」で複数回コールバックが来る。
        // continuation を二度 resume するとクラッシュするので1回に固定する
        options.deliveryMode = .highQualityFormat

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxPixelSize, height: maxPixelSize),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.8))
            }
        }
    }
}
