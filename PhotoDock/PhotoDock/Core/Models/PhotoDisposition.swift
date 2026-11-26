//
//  PhotoDisposition.swift
//  PhotoDock
//

import Foundation

/// 写真1枚に対して、ユーザーが選んだ対応。
///
/// スキャン済み記録（`ScanRecord`）とは別に保存する。あちらは消しても診断し直せば戻るキャッシュだが、
/// こちらは**ユーザーが決めたこと**なので、消えたら戻せない。
/// 持つのは写真の ID・選んだ対応・写っていた種類だけ（読み取った文字は持たない方針のまま）
struct PhotoDisposition: Sendable, Equatable, Codable, Identifiable {
    // String の raw value は保存形式のため
    enum Action: String, Sendable, Equatable, Codable, CaseIterable {
        /// 「問題なしにする」。写真はそのまま残る
        case dismissed
        /// 非表示アルバムへ移した。写真はアプリから見えなくなる
        case hidden
        /// 削除した。写真はライブラリから無くなる（30日は「最近削除した項目」に残る）
        case deleted
    }

    let assetID: String
    let action: Action
    let decidedAt: Date
    /// 対応を決めたときの、写真の編集日時。「問題なし」は、写真がこの後に編集されたら外す
    /// （切り抜きや加工で、写っているものが変わりうる）
    let modificationDate: Date?
    /// 対応を決めたときに写っていた種類。
    /// 非表示・削除した写真はもう読めず、記録も消されうるので、どの項目の「対応済み」に数えるかをここで持つ
    let kinds: [FindingKind]
    /// 写真を撮った日。非表示・削除した写真を、あとで一覧に出すために控える
    /// （写真はもう読めないので、ここに無ければ分からない）。
    /// 既定値を持つのは、この項目を後から足したため（memberwise init の既存呼び出しを壊さない）
    var takenAt: Date?

    var id: String { assetID }
}
