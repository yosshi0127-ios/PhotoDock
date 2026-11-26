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
