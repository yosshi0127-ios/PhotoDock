//
//  LibraryScanOutcome.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

enum LibraryScanOutcome: Sendable, Equatable {
    case unavailable(PhotoLibraryAccess)                          // スキャンできなかった。理由が入る
    case scanned(access: PhotoLibraryAccess, inventory: LibraryInventory)  // full か limited のときだけ
}
