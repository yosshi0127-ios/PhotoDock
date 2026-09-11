//
//  DependencyValues+ScanRecords.swift
//  PhotoDock
//

import Dependencies

// スキャン済み記録の保存先。2回目以降の短縮・中断再開・一覧の復元の土台。
// preview はメモリ上に数件の記録を積み、「前回の診断結果がある」状態で画面が成立するようにする。
private enum ScanRecordRepositoryKey: DependencyKey {
    static let liveValue: any ScanRecordRepository = SwiftDataScanRecordRepository()
    static let previewValue: any ScanRecordRepository = InMemoryScanRecordRepository(
        records: InMemoryScanRecordRepository.previewSeed
    )
    static let testValue: any ScanRecordRepository = UnimplementedScanRecordRepository()
}

extension DependencyValues {
    var scanRecords: any ScanRecordRepository {
        get { self[ScanRecordRepositoryKey.self] }
        set { self[ScanRecordRepositoryKey.self] = newValue }
    }
}
