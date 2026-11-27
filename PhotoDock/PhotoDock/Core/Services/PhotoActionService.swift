//
//  PhotoActionService.swift
//  PhotoDock
//

/// 写真ライブラリを書き換える操作。**確認は OS が出す**（非表示も削除も、毎回ユーザーに聞く）。
/// 元の画像は編集しない。非表示は写真アプリで解除でき、削除は「最近削除した項目」に30日残る
///
/// 何枚でも1回で渡す。OS の確認は、まとめて1回になる（1枚ずつ呼ぶと、枚数ぶん確認が出る）。
/// 1枚も見つからなければ `.notFound`。一部だけ見つからないときは、見つかった分を実行して `.done`
/// （見つからない写真は、もうライブラリに無い）
protocol PhotoActionService: Sendable {
    /// 非表示アルバムへ移す
    func hide(assetIDs: [String]) async -> PhotoActionOutcome

    /// 削除する（「最近削除した項目」へ）
    func delete(assetIDs: [String]) async -> PhotoActionOutcome
}
