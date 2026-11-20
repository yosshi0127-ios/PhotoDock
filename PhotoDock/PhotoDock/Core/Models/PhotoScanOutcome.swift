//
//  PhotoScanOutcome.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

/// 1枚の写真を診断した結果。
///
/// `[Finding]` だけを返さないのは、iCloud にあって診断できなかった写真が
/// 「所見0件 = 問題なし」として集計されるのを防ぐため。
/// 「診断して何も無かった」と「診断できなかった」は別の事実。
enum PhotoScanOutcome: Sendable, Equatable {
    /// 診断できた。0件もありうる（この場合だけ「問題なし」と言える）
    case scanned([Finding])
    /// 端末に元ファイルが無く、ダウンロードは許可されていない（iCloud 最適化）
    case notAvailableLocally
    /// ダウンロードを試したが iCloud 側にも実体が無かった
    case unavailableInCloud
    /// 見つからない・読めない
    case missing
    /// 画像は取れたが、文字を読む処理が失敗した。所見の有無は分からないので
    /// 「診断できた・0件」とは区別する（次回のスキャンでやり直す）
    case failed
}
