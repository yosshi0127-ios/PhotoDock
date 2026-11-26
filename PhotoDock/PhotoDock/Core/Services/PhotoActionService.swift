//
//  PhotoActionService.swift
//  PhotoDock
//

/// 写真ライブラリを書き換える操作。**確認は OS が出す**（非表示も削除も、毎回ユーザーに聞く）。
/// 元の画像は編集しない。非表示は写真アプリで解除でき、削除は「最近削除した項目」に30日残る
protocol PhotoActionService: Sendable {
    /// 非表示アルバムへ移す
    func hide(assetID: String) async -> PhotoActionOutcome

    /// 削除する（「最近削除した項目」へ）
    func delete(assetID: String) async -> PhotoActionOutcome
}
