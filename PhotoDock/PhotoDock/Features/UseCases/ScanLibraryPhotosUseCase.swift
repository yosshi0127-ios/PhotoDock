//
//  ScanLibraryPhotosUseCase.swift
//  PhotoDock
//

/// 全量スキャン（第2段）。1枚ずつ ScanPhotoUseCase に通し、完了順に結果を流す。
/// 依存は ScanPhotoUseCase 経由なので、ここは @Dependency を持たない。
struct ScanLibraryPhotosUseCase: Sendable {
    private let scanPhoto = ScanPhotoUseCase()

    /// 同時実行数を一定に保ちながら診断し、終わったものから流す。
    /// concurrency を上げすぎても速くならない（Vision が内部で並列化するので競合する）。
    func callAsFunction(
        assetIDs: [String],
        quality: ScanQuality,
        concurrency: Int = 4
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
