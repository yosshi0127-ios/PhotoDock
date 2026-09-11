//
//  ScanRecordRepository.swift
//  PhotoDock
//

import Foundation

/// スキャン済み記録の保存と読み出し。実装は SwiftData。
///
/// 契約:
/// - `save` は **1レコード1トランザクション**。途中で落ちても部分書き込みが残らない
/// - 同じ assetID への `save` は上書き（インデックスはただのキャッシュ。真実は最新のスキャン）
/// - **throws にしている**。検出器（OCR / 顔）は「失敗 = 空配列」で続行する契約だが、
///   保存の失敗を空に丸めると「未スキャン」と区別できなくなる。呼ぶ側（UseCase）が握って判断する
protocol ScanRecordRepository: Sendable {
    /// 全件。全量スキャンの開始時に1回読んで辞書にする（3万件でも数MB）
    func allRecords() async throws -> [ScanRecord]

    func save(_ record: ScanRecord) async throws

    /// 記録をすべて消す。本文は持たないが「どの写真に何があったか」は残るので、ユーザーが消せる手段は必要
    func deleteAll() async throws
}
