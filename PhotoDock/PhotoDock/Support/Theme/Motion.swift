//
//  Motion.swift
//  PhotoDock
//

import SwiftUI

/// 動きの速さと質。**View からは必ずここを通す**（その場で `.spring(...)` を書かない）。
///
/// 動きは、状態が変わったことを伝えるために使う（数字が増えた・判定が変わった・押せた）。飾りでは入れない。
/// 「視差効果を減らす」がオンの人には、位置や大きさが動くものを止める（`motion(_:)` を通す）
enum Motion {
    /// 数字や文言の切り替え、押したときの戻り
    static let quick = Animation.snappy(duration: 0.3)
    /// 画面の中身が入れ替わるとき（診断中 → 診断完了）
    static let settle = Animation.smooth(duration: 0.45)
    /// 判定が変わった・出た、を伝える弾み
    static let bounce = Animation.bouncy(duration: 0.5, extraBounce: 0.15)
    /// 総合判定の丸を、線で描く
    static let draw = Animation.easeOut(duration: 0.7)
    /// 押しているあいだの縮み
    static let pressedScale: CGFloat = 0.97
}

extension View {
    /// 「視差効果を減らす」がオンなら、動かさない。数字の切り替えのような、その場の変化はそのまま伝わる
    func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(ReducibleMotion(animation: animation, value: value))
    }
}

private struct ReducibleMotion<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
