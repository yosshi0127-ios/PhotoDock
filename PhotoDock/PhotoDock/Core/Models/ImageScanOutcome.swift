//
//  ImageScanOutcome.swift
//  PhotoDock
//

/// 画像データ1枚を診断した結果。取得はもう済んでいるので、
/// `PhotoScanOutcome` のうち「取れなかった」系を除いた2通りだけになる
enum ImageScanOutcome: Sendable, Equatable {
    /// 診断できた。0件もありうる（この場合だけ「問題なし」と言える）
    case scanned([Finding])
    /// 文字を読む処理が失敗した。所見の有無は分からない
    case failed
}
