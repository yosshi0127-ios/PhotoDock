//
//  ScanSummary.swift
//  PhotoDock
//

/// 全量スキャンの集計。1枚終わるたびに更新され、そのまま進捗表示にも使う。
/// 「所見の件数」ではなく「写真の枚数」を数える（ユーザーが対処する単位は写真なので）。
struct ScanSummary: Sendable, Equatable {
    /// 診断できた枚数（所見ゼロも含む）
    var scanned: Int
    /// 端末に無く、ダウンロードは許可されていなかった枚数（トグルをオンにすれば減る）
    var notAvailableLocally: Int
    /// ダウンロードを試したが iCloud 側にも実体が無かった枚数（誰にもどうしようもない）。
    /// 既定値を持つのは、この項目を後から足したため（memberwise init の既存呼び出しを壊さない）
    var unavailableInCloud: Int = 0
    /// 写真が見つからなかった枚数
    var missing: Int
    /// 危険な所見を含む写真の枚数
    var dangerPhotos: Int
    /// 要注意どまりの所見を含む写真の枚数。danger と混在する写真は danger にだけ数える
    var cautionPhotos: Int

    static let empty = ScanSummary(
        scanned: 0,
        notAvailableLocally: 0,
        missing: 0,
        dangerPhotos: 0,
        cautionPhotos: 0
    )

    /// 処理が終わった枚数。進捗の分子になる
    var completed: Int { scanned + notAvailableLocally + unavailableInCloud + missing }

    /// 所見が1件でもあった写真の枚数
    var flaggedPhotos: Int { dangerPhotos + cautionPhotos }
}
