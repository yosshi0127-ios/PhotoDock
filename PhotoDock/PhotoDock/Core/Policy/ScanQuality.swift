//
//  ScanQuality.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

enum ScanQuality: Sendable, CaseIterable {
    case quick
    case precise

    /// 長辺の最大ピクセル数。値は暫定（Phase 0 の実測で確定）
    var maxPixelSize: Int {
        switch self {
        case .quick: 1_024
        case .precise: 3_000
        }
    }
}
