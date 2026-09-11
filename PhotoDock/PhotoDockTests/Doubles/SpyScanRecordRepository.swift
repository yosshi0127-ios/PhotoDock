//
//  SpyScanRecordRepository.swift
//  PhotoDockTests
//

import Foundation
@testable import PhotoDock

/// 呼び出しを記録する `ScanRecordRepository`。
/// 「読めない」「書けない」を再現できるようにしてある — 保存の失敗でスキャンが止まらないことを固定するため。
actor SpyScanRecordRepository: ScanRecordRepository {
    struct Failure: Error {}

    private let stubbedRecords: [ScanRecord]
    private let failsOnLoad: Bool
    private let failsOnSave: Bool

    private(set) var saved: [ScanRecord] = []
    private(set) var loadCallCount = 0
    private(set) var deleteAllCallCount = 0

    init(records: [ScanRecord] = [], failsOnLoad: Bool = false, failsOnSave: Bool = false) {
        self.stubbedRecords = records
        self.failsOnLoad = failsOnLoad
        self.failsOnSave = failsOnSave
    }

    func allRecords() throws -> [ScanRecord] {
        loadCallCount += 1
        if failsOnLoad { throw Failure() }
        return stubbedRecords
    }

    func save(_ record: ScanRecord) throws {
        if failsOnSave { throw Failure() }
        saved.append(record)
    }

    func deleteAll() {
        deleteAllCallCount += 1
    }
}
