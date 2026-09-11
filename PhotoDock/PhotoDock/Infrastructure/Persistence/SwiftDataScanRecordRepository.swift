//
//  SwiftDataScanRecordRepository.swift
//  PhotoDock
//

import Foundation
import SwiftData

/// SwiftData による保存。@ModelActor なので ModelContext への操作はこの actor の中に閉じ、
/// Swift 6 の隔離チェックを素直に通る（ModelContext は Sendable でない）。
/// protocol の async 要件は actor の同期メソッドで満たせる（外から呼べば暗黙に await）。
@ModelActor
actor SwiftDataScanRecordRepository: ScanRecordRepository {

    /// 本番用。永続ストアが開けない（ディスク破損など）ときはメモリ上で続ける —
    /// インデックスはただのキャッシュなので、無くてもアプリは動く
    init() {
        let schema = Schema([ScanRecordEntity.self])
        let container: ModelContainer

        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            // メモリ専用の生成はディスクに触らないので、ここが失敗する状況はもう手の打ちようがない
            // swiftlint:disable:next force_try
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }

        self.init(modelContainer: container)
    }

    func allRecords() throws -> [ScanRecord] {
        try modelContext.fetch(FetchDescriptor<ScanRecordEntity>()).compactMap { $0.toRecord() }
    }

    /// 1レコード1トランザクション。同じ assetID があれば上書き
    func save(_ record: ScanRecord) throws {
        let assetID = record.assetID
        var descriptor = FetchDescriptor<ScanRecordEntity>(predicate: #Predicate { $0.assetID == assetID })
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            try existing.update(from: record)
        } else {
            modelContext.insert(try ScanRecordEntity(record))
        }

        try modelContext.save()
    }

    func deleteAll() throws {
        try modelContext.delete(model: ScanRecordEntity.self)
        try modelContext.save()
    }
}
