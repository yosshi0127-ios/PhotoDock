//
//  ScanRecordPolicy.swift
//  PhotoDock
//

/// スキャン済み記録が「今回の要求に対してまだ有効か」を決める。純粋関数。
///
/// 品質は単調に上がる: 一括スキャンは「要求品質 > 記録品質、または編集済み」のアセットだけ処理し、
/// 高品質側が常に勝つ。インデックスはただのキャッシュなので、迷ったら再スキャンに倒す。
struct ScanRecordPolicy: Sendable {

    /// true なら診断し直す。false なら記録をそのまま使ってよい
    func needsRescan(
        record: ScanRecord?,
        asset: AssetMetadata,
        quality: ScanQuality,
        generation: String
    ) -> Bool {
        guard let record else { return true }

        // 写真が編集された。切り抜きや加工で写っているものが変わりうる
        if record.modificationDate != asset.modificationDate { return true }

        // 要求のほうが高品質。逆（記録が精密・要求がクイック）は記録を使う
        if quality > record.quality { return true }

        // OS が変わった = Vision の世代が変わった。同じ写真でも検出結果が変わりうる
        if record.generation != generation { return true }

        // 「取れなかった」記録は診断の事実ではない。前回 iCloud 上にあった写真が
        // 今回は端末に来ているかもしれないので毎回再挑戦する（取得の失敗は一瞬で分かる）
        guard case .scanned = record.outcome else { return true }

        return false
    }
}
