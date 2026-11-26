//
//  SwiftDataPhotoDispositionRepository.swift
//  PhotoDock
//

import Foundation
import SwiftData

/// SwiftData による保存。作りは `SwiftDataScanRecordRepository` と同じ（@ModelActor に閉じる）。
///
/// **スキャン済み記録とは別のファイルに保存する**（`Dispositions.store`）。
/// 記録は「すべて消す」ことができるキャッシュで、ユーザーが決めた対応まで一緒に消えてはいけない
@ModelActor
actor SwiftDataPhotoDispositionRepository: PhotoDispositionRepository {

    /// 本番用。永続ストアが開けないときはメモリ上で続ける。
    /// その間に決めた対応はアプリを終了すると消えるが、開けないまま落とすよりは、診断結果を見られるほうを選ぶ
    init() {
        let schema = Schema([PhotoDispositionEntity.self])
        let container: ModelContainer

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("Dispositions", schema: schema)]
            )
        } catch {
            // メモリ専用の生成はディスクに触らないので、ここが失敗する状況はもう手の打ちようがない
            // swiftlint:disable:next force_try
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("Dispositions", schema: schema, isStoredInMemoryOnly: true)]
            )
        }

        self.init(modelContainer: container)
    }

    func allDispositions() throws -> [PhotoDisposition] {
        try modelContext.fetch(FetchDescriptor<PhotoDispositionEntity>()).compactMap { $0.toDisposition() }
    }

    func save(_ disposition: PhotoDisposition) throws {
        if let existing = try entity(assetID: disposition.assetID) {
            existing.update(from: disposition)
        } else {
            modelContext.insert(PhotoDispositionEntity(disposition))
        }
        try modelContext.save()
    }

    func remove(assetID: String) throws {
        guard let existing = try entity(assetID: assetID) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func entity(assetID: String) throws -> PhotoDispositionEntity? {
        var descriptor = FetchDescriptor<PhotoDispositionEntity>(predicate: #Predicate { $0.assetID == assetID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
