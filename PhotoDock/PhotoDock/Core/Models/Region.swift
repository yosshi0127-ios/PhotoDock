//
//  Region.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// 画像内の矩形領域。**左上原点・0...1 正規化**
struct Region: Sendable, Equatable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
