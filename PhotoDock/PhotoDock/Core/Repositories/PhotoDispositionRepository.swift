//
//  PhotoDispositionRepository.swift
//  PhotoDock
//

/// 写真への対応（問題なし・非表示・削除）の保存先。写真1枚につき1件
protocol PhotoDispositionRepository: Sendable {
    /// 全件。結果票を作るときに1回読む（対応した写真の数だけなので少ない）
    func allDispositions() async throws -> [PhotoDisposition]

    /// 同じ写真の対応があれば上書きする
    func save(_ disposition: PhotoDisposition) async throws

    /// 対応を取り消す（「問題なし」を未対応に戻す）。無ければ何もしない
    func remove(assetID: String) async throws
}
