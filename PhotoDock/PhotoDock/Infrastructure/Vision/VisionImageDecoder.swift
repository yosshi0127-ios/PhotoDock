//
//  VisionImageDecoder.swift
//  PhotoDock
//

import Foundation
import ImageIO

/// 復号と縮小を同時に行う。EXIF の向きも適用するので、以降は回転後の画像として扱える。
/// OCR と顔検出が同じ手順を使うことが重要 — 縮小率や向きの扱いが違うと、
/// 両者の正規化座標がずれて詳細画面で枠が合わなくなる。
enum VisionImageDecoder {
    static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
