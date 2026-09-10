//
//  ScanLibraryPhotosUseCase.swift
//  PhotoDock
//

/// 全量スキャン（第2段）。1枚ずつ ScanPhotoUseCase に通し、完了順に結果を流す。
/// 依存は ScanPhotoUseCase 経由なので、ここは @Dependency を持たない。
struct ScanLibraryPhotosUseCase: Sendable {
    private let scanPhoto = ScanPhotoUseCase()

    /// 同時実行数を一定に保ちながら診断し、終わったものから流す。
    ///
    /// 既定が 2 なのは実測による（162枚・1170x2532・シミュレータ）:
    /// 並列1で 44.5秒、2で 41.5秒、4で 41.4秒、**8 は数分経っても終わらない**。
    /// Vision が内部で全コアを使うので外側の並列化はほぼ効かず、増やすと画像の
    /// デコードと推論コンテキストが同時に載ってメモリで破綻する。
    /// 実際の写真は 4032x3024 とさらに大きいので、実機ではより少ない数で危険域に入る。
    func callAsFunction(
        assetIDs: [String],
        quality: ScanQuality,
        concurrency: Int = 2
    ) -> AsyncStream<ScannedPhoto> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: ScannedPhoto.self) { group in
                    var remaining = assetIDs.makeIterator()

                    // 先に concurrency 枚だけ走らせる
                    for _ in 0..<max(1, concurrency) {
                        guard let id = remaining.next() else { break }
                        _ = group.addTaskUnlessCancelled { await self.scan(id, quality: quality) }
                    }

                    // 1枚終わるたびに次を1枚足して、走っている数を保つ
                    for await scanned in group {
                        continuation.yield(scanned)

                        // 消費側が離脱したら積むのをやめる。addTaskUnlessCancelled では
                        // 止まらない（子タスクにキャンセルは伝播しているのに追加は通る）
                        if Task.isCancelled { break }

                        guard let id = remaining.next() else { continue }
                        group.addTask { await self.scan(id, quality: quality) }
                    }
                }

                continuation.finish()
            }

            // 画面を離れてストリームが捨てられたら、走っているスキャンも止める
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func scan(_ assetID: String, quality: ScanQuality) async -> ScannedPhoto {
        ScannedPhoto(assetID: assetID, outcome: await scanPhoto(assetID: assetID, quality: quality))
    }
}
