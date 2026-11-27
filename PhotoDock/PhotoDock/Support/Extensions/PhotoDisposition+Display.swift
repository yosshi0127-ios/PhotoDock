//
//  PhotoDisposition+Display.swift
//  PhotoDock
//

import Foundation

extension PhotoDisposition.Action {
    /// 対処したあとの言い方（「削除 ・ 11月26日」）
    var pastLabel: String {
        switch self {
        case .dismissed: "問題なし"
        case .hidden: "非表示"
        case .deleted: "削除"
        }
    }

    /// 写真アプリの中での行き先。**直接は開けない**ので、行き方を言葉で添える。
    /// 実機（iOS 26・2026-11-27）で、写真アプリの URL を10通り試したが、アルバムまで指定できるものは無かった。
    /// 「写真アプリを開く」で着くのは「コレクション」の画面で、下にスクロールすると「ユーティリティ」があり、
    /// その中に「非表示」と「最近削除した項目」がある（項目の名前は、その実機の表示のとおり）
    var photosAppPath: String? {
        switch self {
        case .dismissed: nil
        case .hidden: "コレクション › ユーティリティ › 非表示"
        case .deleted: "コレクション › ユーティリティ › 最近削除した項目"
        }
    }

    var symbol: String {
        switch self {
        case .dismissed: "checkmark"
        case .hidden: "eye.slash"
        case .deleted: "trash"
        }
    }
}

extension URL {
    /// 写真アプリを開く。**特定の写真や「非表示」アルバムを直接開く方法は、公開されていない**。
    /// この URL も Apple が仕様として公開しているものではない（広く使われていて、iOS 26.2 のシミュレータで写真アプリが前面に来ることは確かめた）。
    /// 動かなくなっても、ボタンが何もしなくなるだけで、ほかの機能には影響しない
    static let photosApp = URL(string: "photos-redirect://")!   // swiftlint:disable:this force_unwrapping
}
