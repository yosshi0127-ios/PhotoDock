//
//  FaceDetectionService.swift
//  PhotoDock
//

import Foundation

/// 画像から顔の位置と向きを検出する。誰の顔かは扱わない。
///
/// 契約: **検出できない環境では空配列を返して続ける**。
/// Vision の顔検出はシミュレータで動かない（code 9）ので、失敗を throw にすると
/// 開発中ずっと落ち続けるうえ、実機でも1枚の失敗で数万枚のスキャンが止まる。
protocol FaceDetectionService: Sendable {
    func detectFaces(in data: Data, maxPixelSize: Int) async -> [DetectedFace]
}
