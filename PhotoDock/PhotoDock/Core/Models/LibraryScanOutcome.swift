//
//  LibraryScanOutcome.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

enum LibraryScanOutcome: Sendable, Equatable {
    case unavailable(PhotoLibraryAccess)  // スキャンできなかった。理由が入る

    /// full か limited のときだけ。
    /// assets は第2段（全量スキャン）の対象で、対象範囲の絞り込みにも使う
    /// （すべて / スクショのみ / 期間 は isScreenshot と creationDate で決まる）
    case scanned(access: PhotoLibraryAccess, inventory: LibraryInventory, assets: [AssetMetadata])
}
