//
//  ScannedPhoto.swift
//  PhotoDock
//

/// 全量スキャンで1枚を診断し終えた結果。完了順に1件ずつ流れる。
/// 結果の種類は1枚経路と同じなので、PhotoScanOutcome をそのまま包む。
struct ScannedPhoto: Sendable, Equatable {
    let assetID: String
    let outcome: PhotoScanOutcome
}
