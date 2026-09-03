//
//  PhotoLibraryAccess.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/01.
//

///  写真ライブラリへのアクセス許可の状態
enum PhotoLibraryAccess {
    case notDetermined
    case denied
    case restricted
    case limited
    case full
}
