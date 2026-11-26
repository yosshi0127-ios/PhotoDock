//
//  ReportRemovedPhoto.swift
//  PhotoDock
//

import Foundation

/// 非表示にした・削除した写真の、対応済みの一覧での1行。
/// 写真そのものは、もうアプリから読めない。対処の記録に残したことだけで作る
/// （画像は残さない。危険な写真を消したのに、その縮小画像がアプリに残っては意味がない）
struct ReportRemovedPhoto: Sendable, Equatable, Identifiable {
    let assetID: String
    /// 非表示か、削除か
    let action: PhotoDisposition.Action
    /// 撮った日。記録していなければ nil（この項目を足す前に対処した写真）
    let takenAt: Date?
    /// 対処した日時
    let decidedAt: Date
    /// 写っていた種類。結果票の表と同じ順
    let kinds: [FindingKind]

    var id: String { assetID }
}
