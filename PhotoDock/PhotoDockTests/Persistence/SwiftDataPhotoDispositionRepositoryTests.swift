//
//  SwiftDataPhotoDispositionRepositoryTests.swift
//  PhotoDockTests
//

import Foundation
import SwiftData
import Testing
@testable import PhotoDock

/// 対応状況の保存。ディスクには触らず、メモリ上のストアで往復を確かめる
@Suite("SwiftDataPhotoDispositionRepository")
struct SwiftDataPhotoDispositionRepositoryTests {
    private let day = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeRepository() throws -> SwiftDataPhotoDispositionRepository {
        let schema = Schema([PhotoDispositionEntity.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return SwiftDataPhotoDispositionRepository(modelContainer: container)
    }

    private func disposition(_ id: String, _ action: PhotoDisposition.Action, kinds: [FindingKind] = [.address]) -> PhotoDisposition {
        PhotoDisposition(
            assetID: id, action: action, decidedAt: day, modificationDate: day, kinds: kinds,
            takenAt: day.addingTimeInterval(-86_400)
        )
    }

    @Test("保存した対応が、そのまま読める")
    func roundTrip() async throws {
        let repository = try makeRepository()
        let saved = disposition("a", .hidden, kinds: [.cardNumber, .address])

        try await repository.save(saved)

        #expect(try await repository.allDispositions() == [saved])
    }

    @Test("同じ写真の対応は上書きする（1枚につき1件）")
    func saveOverwrites() async throws {
        let repository = try makeRepository()

        try await repository.save(disposition("a", .dismissed))
        try await repository.save(disposition("a", .deleted))

        #expect(try await repository.allDispositions() == [disposition("a", .deleted)])
    }

    @Test("取り消すと、その写真の対応だけが消える")
    func removeDeletesOnlyThatPhoto() async throws {
        let repository = try makeRepository()
        try await repository.save(disposition("a", .dismissed))
        try await repository.save(disposition("b", .dismissed))

        try await repository.remove(assetID: "a")

        #expect(try await repository.allDispositions().map(\.assetID) == ["b"])
    }

    @Test("対応の無い写真を取り消しても、何も起きない")
    func removeMissingIsNoop() async throws {
        let repository = try makeRepository()

        try await repository.remove(assetID: "none")

        #expect(try await repository.allDispositions().isEmpty)
    }

    /// 将来の版で対応の種類が増えたあと、古い版で開いたときに落ちないこと
    @Test("知らない対応の名前の行は読み飛ばし、知らない種類はその種類だけを落とす")
    func skipsUnknownValues() {
        let unknownAction = PhotoDispositionEntity(
            assetID: "a", action: "archived", decidedAt: day, modificationDate: nil, kinds: ["address"]
        )
        let unknownKind = PhotoDispositionEntity(
            assetID: "b", action: "hidden", decidedAt: day, modificationDate: nil, kinds: ["address", "futureKind"]
        )

        #expect(unknownAction.toDisposition() == nil)
        #expect(unknownKind.toDisposition()?.kinds == [.address])
    }

    /// 撮った日は後から足した項目。前の版で保存した行（撮った日なし）も読めること
    @Test("撮った日の無い行も読める")
    func readsRowWithoutTakenAt() {
        let legacy = PhotoDispositionEntity(
            assetID: "a", action: "deleted", decidedAt: day, modificationDate: nil, kinds: ["cardNumber"]
        )

        #expect(legacy.toDisposition() == PhotoDisposition(
            assetID: "a", action: .deleted, decidedAt: day, modificationDate: nil, kinds: [.cardNumber]
        ))
    }
}
