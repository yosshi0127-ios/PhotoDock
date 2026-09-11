//
//  ScanLibraryPhotosUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// 全量スキャン（第2段）。記録が有効な写真は診断せずに記録を流し、
/// 残りだけを ScanPhotoUseCase に通して完了順に流す。診断した分は記録に保存する。
///
/// 2回目以降の短縮はここで生まれる。3万枚のうち新しい写真が100枚なら、100枚分の時間で終わる。
struct ScanLibraryPhotosUseCase: Sendable {
    @Dependency(\.scanRecords) private var scanRecords
    @Dependency(\.network) private var network

    private let scanPhoto = ScanPhotoUseCase()
    private let recordPolicy = ScanRecordPolicy()

    /// 同時実行数を一定に保ちながら診断し、終わったものから流す。
    ///
    /// 既定が 2 なのは実測による（162枚・1170x2532・シミュレータ）:
    /// 並列1で 44.5秒、2で 41.5秒、4で 41.4秒、**8 は数分経っても終わらない**。
    /// Vision が内部で全コアを使うので外側の並列化はほぼ効かず、増やすと画像の
    /// デコードと推論コンテキストが同時に載ってメモリで破綻する。
    ///
    /// allowsDownload は「iCloud の写真も診断する」のユーザー設定。true でも回線が
    /// 従量課金なら通信しない（判定はここで1回だけ）。
    func callAsFunction(
        assets: [AssetMetadata],
        quality: ScanQuality,
        allowsDownload: Bool = false,
        concurrency: Int = 2
    ) -> AsyncStream<ScanRecord> {
        AsyncStream { continuation in
            let task = Task {
                // 記録はここで1回だけ読む。3万件でも辞書にして数MB
                let index = await loadIndex()
                // Vision の世代の代理。OS が変われば記録は無効になる
                let generation = ProcessInfo.processInfo.operatingSystemVersionString
                let mode = await fetchMode(allowsDownload: allowsDownload, quality: quality)

                // 記録が有効な写真は診断しない。即時に流すので進捗が一気に進む
                var toScan: [AssetMetadata] = []
                for asset in assets {
                    let record = index[asset.id]
                    if let record, !recordPolicy.needsRescan(record: record, asset: asset, quality: quality, generation: generation) {
                        continuation.yield(record)
                    } else {
                        toScan.append(asset)
                    }
                }

                await withTaskGroup(of: ScanRecord.self) { group in
                    var remaining = toScan.makeIterator()

                    // 先に concurrency 枚だけ走らせる
                    for _ in 0..<max(1, concurrency) {
                        guard let asset = remaining.next() else { break }
                        group.addTask { await self.scanAndStore(asset, quality: quality, mode: mode, generation: generation) }
                    }

                    // 1枚終わるたびに次を1枚足して、走っている数を保つ
                    for await record in group {
                        continuation.yield(record)

                        // 消費側が離脱したら積むのをやめる。addTaskUnlessCancelled では
                        // 止まらない（子タスクにキャンセルは伝播しているのに追加は通る）
                        if Task.isCancelled { break }

                        guard let asset = remaining.next() else { continue }
                        group.addTask { await self.scanAndStore(asset, quality: quality, mode: mode, generation: generation) }
                    }
                }

                continuation.finish()
            }

            // 画面を離れてストリームが捨てられたら、走っているスキャンも止める
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 読めなければ空 = 全件を「記録なし」として診断する。キャッシュなので失っても壊れない
    private func loadIndex() async -> [String: ScanRecord] {
        guard let records = try? await scanRecords.allRecords() else { return [:] }
        return Dictionary(records.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })
    }

    /// ダウンロードは「ユーザーが許可し、かつ通信してよい回線」のときだけ。
    /// 許可がオフなら回線を見にも行かない。途中で切れた分は取得の失敗として記録され、次回再挑戦される
    private func fetchMode(allowsDownload: Bool, quality: ScanQuality) async -> PixelFetchMode {
        guard allowsDownload, await network.isOnUnmeteredNetwork() else { return .localOnly }
        return .downloadIfNeeded(maxPixelSize: quality.maxPixelSize)
    }

    /// 診断して記録に変換し、保存する。保存に失敗しても記録は流す
    /// （1枚の保存失敗で3万枚のスキャンを止めない。その写真は次回また診断されるだけ）
    private func scanAndStore(
        _ asset: AssetMetadata,
        quality: ScanQuality,
        mode: PixelFetchMode,
        generation: String
    ) async -> ScanRecord {
        let outcome = await scanPhoto(assetID: asset.id, quality: quality, mode: mode)
        let record = ScanRecord(
            ScannedPhoto(assetID: asset.id, outcome: outcome),
            asset: asset,
            quality: quality,
            generation: generation,
            scannedAt: .now
        )
        try? await scanRecords.save(record)
        return record
    }
}
