//
//  PhotoDetailStateTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 写真詳細の「問題なしにする」と取り消し。
/// 「保存できたときだけ表示を変える」「写真ライブラリには触らない」を固定する
@Suite("PhotoDetailState")
@MainActor
struct PhotoDetailStateTests {
    private let edited = Date(timeIntervalSince1970: 1_760_000_000)

    private var record: ScanRecord {
        ScanRecord(
            assetID: "a", modificationDate: edited, scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
            quality: .precise, generation: "test",
            outcome: .scanned([
                StoredFinding(kind: .phoneNumber, severity: .caution, region: .test),
                StoredFinding(kind: .address, severity: .caution, region: .test)
            ])
        )
    }

    private func makeState(dispositions: SpyPhotoDispositionRepository) -> PhotoDetailState {
        withDependencies {
            $0.photoDispositions = dispositions
            // 画像は取れなくてよい（所見と対応だけを見る）
            $0.pixelSource = SpyPixelSourceService(outcome: .missing)
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            PhotoDetailState()
        }
    }

    @Test("開いたときは、一覧の時点の対応状況を引き継ぐ")
    func showKeepsHandledState() async {
        let state = makeState(dispositions: SpyPhotoDispositionRepository())

        await state.show(record: record, isHandled: true)

        #expect(state.isDismissed)
        #expect(state.findings.map(\.kind) == [.address, .phoneNumber])
        #expect(!state.isLoadingImage)
    }

    @Test("問題なしにすると、写っていた種類と編集日時を付けて保存する")
    func dismissSaves() async {
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions)

        await state.dismiss(record: record)

        #expect(state.isDismissed)
        #expect(!state.didFailToSave)
        let saved = await dispositions.saved
        #expect(saved.count == 1)
        #expect(saved.first?.assetID == "a")
        #expect(saved.first?.action == .dismissed)
        #expect(saved.first?.modificationDate == edited)
        #expect(saved.first?.kinds == [.address, .phoneNumber])
    }

    @Test("未対応に戻すと、その写真の対応を消す")
    func reopenRemoves() async {
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions)
        await state.dismiss(record: record)

        await state.reopen(record: record)

        #expect(!state.isDismissed)
        #expect(await dispositions.removedIDs == ["a"])
        #expect(try! await dispositions.allDispositions().isEmpty)
    }

    /// 保存できていないのに「対応済み」と見せると、次に開いたときに未対応に戻って見える
    @Test("保存できなければ、表示は変えずに失敗を出す")
    func dismissFailureKeepsState() async {
        let state = makeState(dispositions: SpyPhotoDispositionRepository(failsOnSave: true))

        await state.dismiss(record: record)

        #expect(!state.isDismissed)
        #expect(state.didFailToSave)
    }

    @Test("取り消しを保存できなければ、対応済みのままにして失敗を出す")
    func reopenFailureKeepsState() async {
        let state = makeState(dispositions: SpyPhotoDispositionRepository(failsOnSave: true))
        await state.show(record: record, isHandled: true)

        await state.reopen(record: record)

        #expect(state.isDismissed)
        #expect(state.didFailToSave)
    }
}
