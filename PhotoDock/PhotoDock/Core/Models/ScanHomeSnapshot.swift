//
//  ScanHomeSnapshot.swift
//  PhotoDock
//

/// ホームを開いたときに分かること。**ここまでは通信もダイアログも無い**（今の状態を読むだけ）。
enum ScanHomeSnapshot: Sendable, Equatable {
    /// まだアクセスを聞いていない。先に約束を見せてから聞く
    case needsPermission
    /// 拒否・機能制限。診断できない
    case unavailable(PhotoLibraryAccess)
    /// 診断できる状態。
    /// - assets: 今ライブラリにある写真（診断の対象）
    /// - report: 今ある写真の記録から作った結果票。まだ1枚も診断していなければ nil
    /// - newPhotoCount: まだ診断していない写真の枚数（記録が無い・編集された・診断の世代が古い）。
    ///   iCloud にあって取れなかった写真は含めない（毎回試すものなので「新しい写真」ではない）
    case ready(access: PhotoLibraryAccess, assets: [AssetMetadata], report: ScanReport?, newPhotoCount: Int)
}
