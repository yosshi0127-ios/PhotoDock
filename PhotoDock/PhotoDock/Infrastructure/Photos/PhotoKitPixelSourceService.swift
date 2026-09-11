//
//  PhotoKitPixelSourceService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

import os
import Photos
import UIKit

struct PhotoKitPixelSourceService: PixelSourceService {
    /// 取得の失敗理由を残す。アセット ID や画像の中身は出さない（エラーの種類とアセットの分類だけ）
    private static let logger = Logger(subsystem: "com.upft.photodock", category: "PixelSource")

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
    ///
    /// ごく一部のアセットは縮小版の生成が iCloud 側でできず PHPhotosErrorDomain -1 で落ちる
    /// （実機で再現。3840x2160 の普通の写真）。そのときだけ元ファイルで取り直す。
    /// それでも取れなければ unavailableInCloud（iCloud 側に実体が無い "Record not found"。
    /// ユーザーにもアプリにもできることは無いが、次回の再挑戦対象には残す）
    private static func downloadedDerivative(of asset: PHAsset, maxPixelSize: Int) async -> PixelSourceOutcome {
        if let data = await derivativeData(of: asset, maxPixelSize: maxPixelSize) {
            return .data(data)
        }

        if let data = await originalData(of: asset) {
            logger.info("縮小版が作れないアセットを元ファイルで取り直した pixels=\(asset.pixelWidth, privacy: .public)x\(asset.pixelHeight, privacy: .public)")
            return .data(data)
        }

        return .unavailableInCloud
    }

    private static func derivativeData(of asset: PHAsset, maxPixelSize: Int) async -> Data? {
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
            ) { image, info in
                if let data = image?.jpegData(compressionQuality: 0.9) {
                    continuation.resume(returning: data)
                } else {
                    Self.logFailure("縮小版", info: info, asset: asset)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// フォールバック専用。元ファイルなので 1枚 1.6MB 前後
    private static func originalData(of asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if data == nil {
                    Self.logFailure("元ファイル", info: info, asset: asset)
                }
                continuation.resume(returning: data)
            }
        }
    }

    /// 「取れなかった」記録になり次回再挑戦されるが、理由が見えないと調整できない。
    /// アセット ID や画像の中身は出さない
    private static func logFailure(_ what: String, info: [AnyHashable: Any]?, asset: PHAsset) {
        let error = info?[PHImageErrorKey] as? NSError
        let cancelled = info?[PHImageCancelledKey] as? Bool ?? false
        logger.error("""
            iCloud から\(what, privacy: .public)を取れなかった: \
            error=\(error?.domain ?? "-", privacy: .public)/\(error?.code ?? 0, privacy: .public) \
            (\(error?.localizedDescription ?? "-", privacy: .public)) \
            cancelled=\(cancelled, privacy: .public) \
            mediaSubtypes=\(asset.mediaSubtypes.rawValue, privacy: .public) \
            sourceType=\(asset.sourceType.rawValue, privacy: .public) \
            pixels=\(asset.pixelWidth, privacy: .public)x\(asset.pixelHeight, privacy: .public)
            """)
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
