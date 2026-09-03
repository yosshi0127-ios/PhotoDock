//
//  GeoCoordinate.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/01.
//

/// 緯度経度のペア
struct GeoCoordinate: Sendable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
}
