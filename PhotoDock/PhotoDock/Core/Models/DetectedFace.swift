//
//  DetectedFace.swift
//  PhotoDock
//

/// 検出された顔1つ。誰の顔かは分からない（個人識別は公開 API に無く、方針としてもやらない）。
/// 写り込みらしさの判定材料になる幾何だけを持つ。
struct DetectedFace: Sendable, Equatable {
    /// 左上原点・0...1 正規化（Region と同じ座標系。Vision の左下原点からの変換は実装側で済ませる）
    let region: Region
    /// 左右の向き（ラジアン）。0 が正面、絶対値が大きいほど横を向いている。
    /// 取れなければ nil — 0 で埋めると「正面だから被写体」と誤判定するので、分からないことは分からないまま持つ
    let yaw: Double?
}
