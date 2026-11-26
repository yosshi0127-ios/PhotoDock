//
//  ReportPhotoFinding.swift
//  PhotoDock
//

/// 写真詳細の所見の1行。1枚の写真の所見を、種類ごとにまとめたもの。
/// 住所が2か所に写っていても、行は「住所」1つ（結果票の項目と同じ単位で見せる）
struct ReportPhotoFinding: Sendable, Equatable, Identifiable {
    let kind: FindingKind
    /// この種類の所見のうち、最も高い段階から決めた判定
    let verdict: ScanReport.Verdict
    /// 写真の中で、この種類が見つかった場所の数（枠の数）
    let placeCount: Int

    var id: FindingKind { kind }
}
