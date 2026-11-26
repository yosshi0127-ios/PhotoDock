//
//  Metrics.swift
//  PhotoDock
//

import CoreGraphics

/// 余白の段階。**View からは必ずここを通す**（数値の直書きをしない）
enum Spacing {
    /// 4: 見出しと補足など、ひとかたまりの中
    static let xxs: CGFloat = 4
    /// 8: 札どうし・ボタンどうし
    static let xs: CGFloat = 8
    /// 12: カードの中の要素どうし
    static let s: CGFloat = 12
    /// 16: カードの内側・カードどうし
    static let m: CGFloat = 16
    /// 20: 画面の左右
    static let l: CGFloat = 20
    /// 24: 節どうし
    static let xl: CGFloat = 24
}

/// 角の丸みと、大きさの決まった部品
enum Metrics {
    /// カード・表・主ボタンの角
    static let cardRadius: CGFloat = 12
    /// 札・小さな囲みの角
    static let tagRadius: CGFloat = 6
    /// 罫線・枠線の太さ
    static let hairlineWidth: CGFloat = 1
    /// 表の1行の高さの下限（指で押せる 44pt を確保する）
    static let rowMinHeight: CGFloat = 46
    /// 主ボタンの高さの下限
    static let actionMinHeight: CGFloat = 52
    /// 総合判定の記号を囲む丸の直径
    static let gradeDiameter: CGFloat = 64
    /// 総合判定の丸の線の太さ
    static let gradeStrokeWidth: CGFloat = 3
    /// 一覧の行に出すサムネイルの一辺
    static let thumbnailSize: CGFloat = 64
    /// 本文の幅の上限。広い画面（iPhone Duo を開いたとき等）で、行の左右が離れすぎないようにする。
    /// 上限なので、通常の iPhone の幅では画面幅のまま変わらない
    static let readableWidth: CGFloat = 480
}
