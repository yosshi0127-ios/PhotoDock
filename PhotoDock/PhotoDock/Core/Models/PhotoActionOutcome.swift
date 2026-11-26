//
//  PhotoActionOutcome.swift
//  PhotoDock
//

/// 写真ライブラリを書き換える操作（非表示・削除）の結果。
/// 「ユーザーがやめた」と「できなかった」を分ける（やめたときに、失敗の文言を出さないため）
enum PhotoActionOutcome: Sendable, Equatable {
    /// 実行された
    case done
    /// iOS の確認で「許可しない」が選ばれた。何も変わっていない
    case cancelled
    /// 写真が見つからない（すでに消えている・非表示になっている）
    case notFound
    /// それ以外の理由でできなかった
    case failed
}
