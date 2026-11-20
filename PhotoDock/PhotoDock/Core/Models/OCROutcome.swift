//
//  OCROutcome.swift
//  PhotoDock
//

/// 文字認識1回の結果。
///
/// 「読んだが文字が無かった」（`recognized([])`）と「読めなかった」（`failed`）を分ける。
/// 混ぜると、失敗した写真が「診断済み・所見なし」として記録に残り、
/// 見ていないものに「問題なし」のお墨付きを与えてしまう
enum OCROutcome: Sendable, Equatable {
    /// 読めた。文字の無い写真では0行（これが大半）
    case recognized([RecognizedText])
    /// 画像として復号できない・推論がエラーを返した
    case failed
}
