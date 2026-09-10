//
//  ScannedPhoto.swift
//  PhotoDock
//

/// 全量スキャンで1枚を診断し終えた結果。完了順に1件ずつ流れる。
/// 結果の種類は1枚経路と同じなので、PhotoScanOutcome をそのまま包む。
struct ScannedPhoto: Sendable, Equatable {
    let assetID: String
    let outcome: PhotoScanOutcome

    /// 所見があった写真か。一覧に出す対象になる。
    /// 「診断できたが所見ゼロ」と「診断できなかった」はどちらも false
    var isFlagged: Bool {
        findings.isEmpty == false
    }

    /// この写真の所見。診断できていなければ空
    var findings: [Finding] {
        if case let .scanned(findings) = outcome { findings } else { [] }
    }
}
