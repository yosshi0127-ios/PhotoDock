//
//  RemovePhotoUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 非表示・削除。「実行されたときだけ対応として残す」「やめたら何も残さない」を固定する
@Suite("RemovePhotoUseCase")
struct RemovePhotoUseCaseTests {
    private let edited = Date(timeIntervalSince1970: 1_760_000_000)
    private let taken = Date(timeIntervalSince1970: 1_740_000_000)

    private var record: ScanRecord {
        ScanRecord(
            assetID: "a", modificationDate: edited, scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .precise, generation: "test",
            outcome: .scanned([
                StoredFinding(kind: .phoneNumber, severity: .caution, region: .test),
                StoredFinding(kind: .cardNumber, severity: .danger, region: .test)
            ])
        )
    }

    private func run(
        _ method: RemovePhotoUseCase.Method,
        actions: SpyPhotoActionService,
        dispositions: SpyPhotoDispositionRepository
    ) async -> PhotoActionOutcome {
        await withDependencies {
            $0.photoActions = actions
            $0.photoDispositions = dispositions
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = RemovePhotoUseCase()
            return await useCase(method, record: record, takenAt: taken)
        }
    }

    @Test("非表示にできたら、非表示として保存する（写っていた種類を残す）")
    func hideSavesDisposition() async {
        let actions = SpyPhotoActionService()
        let dispositions = SpyPhotoDispositionRepository()

        let outcome = await run(.hide, actions: actions, dispositions: dispositions)

        #expect(outcome == .done)
        #expect(await actions.hiddenIDs == ["a"])
        #expect(await actions.deletedIDs.isEmpty)
        let saved = await dispositions.saved
        #expect(saved.map(\.action) == [.hidden])
        // 非表示にした写真はもう読めないので、種類は対応の側に残す（表の順）
        #expect(saved.first?.kinds == [.cardNumber, .phoneNumber])
        // 撮った日も控える（あとで一覧に出すとき、ほかに知る手段が無い）
        #expect(saved.first?.takenAt == taken)
    }

    @Test("削除できたら、削除として保存する")
    func deleteSavesDisposition() async {
        let actions = SpyPhotoActionService()
        let dispositions = SpyPhotoDispositionRepository()

        let outcome = await run(.delete, actions: actions, dispositions: dispositions)

        #expect(outcome == .done)
        #expect(await actions.deletedIDs == ["a"])
        #expect(await actions.hiddenIDs.isEmpty)
        #expect(await dispositions.saved.map(\.action) == [.deleted])
    }

    /// iOS の確認で「許可しない」を選んだ・写真が見つからない・できなかった
    @Test("実行されなかったら、対応として保存しない", arguments: [
        PhotoActionOutcome.cancelled, .notFound, .failed
    ])
    func doesNotSaveUnlessDone(_ result: PhotoActionOutcome) async {
        let dispositions = SpyPhotoDispositionRepository()

        let outcome = await run(.hide, actions: SpyPhotoActionService(outcome: result), dispositions: dispositions)

        #expect(outcome == result)
        #expect(await dispositions.saved.isEmpty)
    }

    /// 写真はもう動いていて、取り消せない。保存の失敗を「できなかった」と返すと、もう一度押させてしまう
    @Test("対応を保存できなくても、実行されたことは変わらない")
    func reportsDoneEvenWhenSaveFails() async {
        let outcome = await run(
            .delete, actions: SpyPhotoActionService(), dispositions: SpyPhotoDispositionRepository(failsOnSave: true)
        )

        #expect(outcome == .done)
    }
}
