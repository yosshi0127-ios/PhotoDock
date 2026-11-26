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
    /// 診断できる状態
    case ready(ScanHomeContent)
}

/// 診断できる状態のホームが表示するもの
struct ScanHomeContent: Sendable, Equatable {
    /// full か limited。limited のときは「全部は見えていない」ことを伝える
    let access: PhotoLibraryAccess
    /// 今ライブラリにある写真（診断の対象）
    let assets: [AssetMetadata]
    /// 今ある写真の記録から作った結果票。まだ1枚も診断していなければ nil
    let report: ScanReport?
    /// 所見のある写真の記録（今ある写真のぶんだけ）。写真の新しい順
    let flagged: [ScanRecord]
    /// まだ診断していない写真の枚数（記録が無い・編集された・診断の世代が古い）。
    /// iCloud にあって取れなかった写真は含めない（毎回試すものなので「新しい写真」ではない）
    let newPhotoCount: Int
    /// ユーザーが選んだ対応（問題なし・非表示・削除）。項目の一覧で、対応済みの写真を分けるのに使う。
    /// 既定値を持つのは、この項目を後から足したため
    var dispositions: [PhotoDisposition] = []

    /// 次の診断で実際に診断する見込みの枚数。新しい写真に、取り寄せを許可していれば iCloud のぶんを足す。
    /// ホームのボタンの枚数と、診断中の残り時間の見積もりで同じ値を使う
    func pendingCount(allowsDownload: Bool) -> Int {
        newPhotoCount + (allowsDownload ? report?.notAvailableLocally ?? 0 : 0)
    }
}
