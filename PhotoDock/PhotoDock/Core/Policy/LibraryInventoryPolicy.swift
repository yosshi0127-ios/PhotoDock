//
//  LibraryInventoryPolicy.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

struct LibraryInventoryPolicy: Sendable {
    func inventory(of assets: [AssetMetadata]) -> LibraryInventory {
        LibraryInventory(
            total: assets.count,
            withLocation: assets.count { $0.coordinate != nil },
            screenshots: assets.count { $0.isScreenshot }
        )
    }
}
