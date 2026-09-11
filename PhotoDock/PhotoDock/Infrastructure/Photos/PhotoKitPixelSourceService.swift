//
//  PhotoKitPixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import Photos
import UIKit

struct PhotoKitPixelSourceService: PixelSourceService {

    /// asset ID で1枚引く。まず端末の元ファイルを試し、無ければ mode に従う。
    @concurrent   // 重い I/O。付けないと呼び出し元のメインスレッドを塞ぐ
    func fetchImageData(for id: String, mode: PixelFetchMode) async -> PixelSourceOutcome {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return .missing
        }

        let local = await Self.localOriginal(of: asset)

        // 端末に元ファイルがあればそれが一番質が高い。無いときだけダウンロードを考える
        guard case .notAvailableLocally = local, case let .downloadIfNeeded(maxPixelSize) = mode else {
            return local
        }

        return await Self.downloadedDerivative(of: asset, maxPixelSize: maxPixelSize)
    }

    /// 端末にある元ファイルのバイト列。取れなかった理由は Outcome で区別する
    private static func localOriginal(of asset: PHAsset) async -> PixelSourceOutcome {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false   // ここでは通信しない

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

    /// iCloud からサーバ側の縮小版を取る（実測: 1,024px 要求で 287KB・0.5秒/枚。元ファイルは 1.6MB）。
    /// 元ファイルを取らないのは容量のため — 時間は往復の遅延で決まるのでほぼ同じ。
    /// 取れなければ notAvailableLocally のまま（次回の再挑戦対象になる）
    private static func downloadedDerivative(of asset: PHAsset, maxPixelSize: Int) async -> PixelSourceOutcome {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        // 既定の .opportunistic は複数回コールバックが来て continuation が二度 resume される
        options.deliveryMode = .highQualityFormat

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxPixelSize, height: maxPixelSize),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if let data = image?.jpegData(compressionQuality: 0.9) {
                    continuation.resume(returning: .data(data))
                } else {
                    continuation.resume(returning: .notAvailableLocally)
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
