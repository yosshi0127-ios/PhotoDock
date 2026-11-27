//
//  DustGrid.swift
//  PhotoDock
//

import SwiftUI
import UIKit

/// 写真を升目の色に置き換えたもの
struct DustGrid {
    let columns: Int
    let rows: Int
    /// 升目の色（行ごとに左から）。r, g, b の順
    private let pixels: [UInt8]

    init?(image: UIImage, columns: Int) {
        guard let source = image.cgImage, image.size.width > 0 else { return nil }
        let rows = max(1, Int((CGFloat(columns) * image.size.height / image.size.width).rounded()))
        var bytes = [UInt8](repeating: 0, count: columns * rows * 4)
        // 描く先の場所は、この閉じた範囲の中でだけ有効（外へ持ち出さない）
        let didDraw = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: columns * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(source, in: CGRect(x: 0, y: 0, width: columns, height: rows))
            return true
        }
        guard didDraw else { return nil }
        self.columns = columns
        self.rows = rows
        self.pixels = bytes
    }

    /// progress は 0（そのまま）から 1（消えきった）。升目ごとに、左ほど早く動き出す
    func draw(in context: inout GraphicsContext, size: CGSize, progress: Double) {
        let cell = CGSize(width: size.width / CGFloat(columns), height: size.height / CGFloat(rows))
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                // 升目ごとに決まった乱れ（毎コマ同じ値になるように、位置から作る）
                let noise = Self.noise(index)
                let delay = Double(column) / Double(columns) * 0.55 + noise * 0.12
                let local = min(1, max(0, (progress - delay) / 0.4))
                guard local < 1 else { continue }

                let eased = local * local
                let drift = CGSize(
                    width: eased * (30 + noise * 70),
                    height: -eased * (20 + Self.noise(index &* 31 &+ 7) * 90)
                )
                let scale = 1 - eased * 0.6
                let rect = CGRect(
                    x: CGFloat(column) * cell.width + drift.width,
                    y: CGFloat(row) * cell.height + drift.height,
                    width: cell.width * scale + 0.5,
                    height: cell.height * scale + 0.5
                )
                let offset = index * 4
                let color = Color(
                    red: Double(pixels[offset]) / 255, green: Double(pixels[offset + 1]) / 255, blue: Double(pixels[offset + 2]) / 255
                )
                context.fill(Path(rect), with: .color(color.opacity(1 - eased)))
            }
        }
    }

    /// 0...1 の、位置で決まる値
    private static func noise(_ seed: Int) -> Double {
        var value = UInt64(truncatingIfNeeded: seed) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        value ^= value >> 33
        value = value &* 0xff51_afd7_ed55_8ccd
        value ^= value >> 33
        return Double(value % 10_000) / 10_000
    }
}
