//
//  PhotoLibraryService.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

/// カメラロールのメタデータを読む。実装は PhotoKit。
protocol PhotoLibraryService: Sendable {
    /// ダイアログは出さない。現状を読むだけ。
    func currentAccess() async -> PhotoLibraryAccess

    /// `notDetermined` のときだけダイアログを出す。拒否された後の再要求はできない。
    func requestAccess() async -> PhotoLibraryAccess

    /// 画像のみ・撮影日時の新しい順。
    /// 権限がないと空配列が返る（0枚と区別できないので、呼ぶ側が先に権限を見る）。
    /// 数万枚を走査するので、呼び出し元のスレッドを塞がないことは実装側の責任。
    func fetchAllAssetMetadata() async -> [AssetMetadata]
}
