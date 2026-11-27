//
//  ReportItemStateTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 項目の一覧で、写真を何枚か選んでまとめて対応する。
/// 「OS の確認が1回で済むように、まとめて1回で渡す」「やめたら何も残さない」を固定する
@Suite("ReportItemState")
@MainActor
struct ReportItemStateTests {
    private let taken = Date(timeIntervalSince1970: 1_740_000_000)

    private func photo(_ id: String, _ kind: FindingKind = .bystanderFace) -> ReportItemPhoto {
        ReportItemPhoto(
            record: ScanRecord(
                assetID: id, modificationDate: nil, scannedAt: Date(timeIntervalSince1970: 1_750_000_000),
                quality: .precise, generation: "test",
                outcome: .scanned([StoredFinding(kind: kind, severity: .caution, region: .test)])
            ),
            takenAt: taken, verdict: .caution, kinds: [kind]
        )
    }

    private func makeState(
        dispositions: SpyPhotoDispositionRepository = SpyPhotoDispositionRepository(),
        actions: SpyPhotoActionService = SpyPhotoActionService()
    ) -> ReportItemState {
        withDependencies {
            $0.photoDispositions = dispositions
            $0.photoActions = actions
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            ReportItemState()
        }
    }

    // MARK: - 選ぶ

    @Test("選んでいないあいだは、押しても選ばれない")
    func toggleNeedsSelectionMode() {
        let state = makeState()

        state.toggle("a")

        #expect(state.selectedIDs.isEmpty)
    }

    @Test("押すと選び、もう一度押すと外す")
    func toggleSelectsAndDeselects() {
        let state = makeState()
        state.beginSelection()

        state.toggle("a")
        state.toggle("b")
        state.toggle("a")

        #expect(state.selectedIDs == ["b"])
    }

    @Test("すべて選択は、全部選んであれば全部外す")
    func toggleAll() {
        let state = makeState()
        state.beginSelection()
        state.toggle("a")

        state.toggleAll(["a", "b", "c"])
        #expect(state.selectedIDs == ["a", "b", "c"])

        state.toggleAll(["a", "b", "c"])
        #expect(state.selectedIDs.isEmpty)
    }

    @Test("キャンセルすると、選んだものを捨てる")
    func cancelClearsSelection() {
        let state = makeState()
        state.beginSelection()
        state.toggle("a")

        state.cancelSelection()

        #expect(!state.isSelecting)
        #expect(state.selectedIDs.isEmpty)
    }

    /// 対応して一覧から消えた写真の印が残っていても、枚数に数えない
    @Test("選んである写真は、いま一覧にあるものだけ")
    func selectedIgnoresMissingPhotos() {
        let state = makeState()
        state.beginSelection()
        state.toggle("a")
        state.toggle("gone")

        #expect(state.selected(in: [photo("a"), photo("b")]).map(\.id) == ["a"])
    }

    // MARK: - まとめて問題なし

    @Test("まとめて問題なしにすると、1枚ずつ対応として保存し、選択を終える")
    func dismissSavesEachPhoto() async {
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions)
        state.beginSelection()

        await state.dismiss([photo("a"), photo("b"), photo("c")])

        let saved = await dispositions.saved
        #expect(saved.map(\.assetID) == ["a", "b", "c"])
        #expect(saved.allSatisfy { $0.action == .dismissed && $0.takenAt == taken })
        #expect(!state.isSelecting)
        #expect(!state.didFailToSave)
    }

    @Test("保存できなかったら、選んだまま残して知らせる")
    func dismissFailureKeepsSelection() async {
        let state = makeState(dispositions: SpyPhotoDispositionRepository(failsOnSave: true))
        state.beginSelection()
        state.toggle("a")

        await state.dismiss([photo("a")])

        #expect(state.didFailToSave)
        #expect(state.isSelecting)
        #expect(state.selectedIDs == ["a"])
    }

    // MARK: - まとめて非表示・削除

    /// 1枚ずつ呼ぶと、OS の確認が枚数ぶん出る
    @Test("まとめて非表示にするときは、1回で渡す")
    func hidePassesAllAtOnce() async {
        let actions = SpyPhotoActionService()
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions, actions: actions)
        state.beginSelection()

        await state.remove(.hide, [photo("a"), photo("b"), photo("c")])

        #expect(await actions.callCount == 1)
        #expect(await actions.hiddenIDs == ["a", "b", "c"])
        #expect(await actions.deletedIDs.isEmpty)
        let saved = await dispositions.saved
        #expect(saved.map(\.assetID) == ["a", "b", "c"])
        #expect(saved.allSatisfy { $0.action == .hidden && $0.kinds == [.bystanderFace] })
        #expect(!state.isSelecting)
    }

    @Test("まとめて削除すると、削除として保存する")
    func deleteSavesAsDeleted() async {
        let actions = SpyPhotoActionService()
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions, actions: actions)
        state.beginSelection()

        await state.remove(.delete, [photo("a"), photo("b")])

        #expect(await actions.callCount == 1)
        #expect(await actions.deletedIDs == ["a", "b"])
        #expect(await dispositions.saved.map(\.action) == [.deleted, .deleted])
    }

    @Test("iOS の確認でやめたら、何も保存せず、選んだまま残す")
    func cancelledKeepsSelection() async {
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions, actions: SpyPhotoActionService(outcome: .cancelled))
        state.beginSelection()
        state.toggle("a")

        await state.remove(.delete, [photo("a")])

        #expect(await dispositions.saved.isEmpty)
        #expect(state.isSelecting)
        #expect(state.selectedIDs == ["a"])
        // やめたのは失敗ではない
        #expect(!state.didFailToRemove)
    }

    @Test("できなかったら、何も保存せずに知らせる", arguments: [PhotoActionOutcome.failed, .notFound])
    func failureIsReported(_ outcome: PhotoActionOutcome) async {
        let dispositions = SpyPhotoDispositionRepository()
        let state = makeState(dispositions: dispositions, actions: SpyPhotoActionService(outcome: outcome))
        state.beginSelection()

        await state.remove(.hide, [photo("a")])

        #expect(await dispositions.saved.isEmpty)
        #expect(state.didFailToRemove)
        #expect(state.isSelecting)
    }

    @Test("1枚も選んでいなければ、何もしない")
    func emptySelectionDoesNothing() async {
        let actions = SpyPhotoActionService()
        let state = makeState(actions: actions)
        state.beginSelection()

        await state.remove(.delete, [])
        await state.dismiss([])

        #expect(await actions.callCount == 0)
        #expect(state.isSelecting)
    }

    /// 対応の保存に失敗しても、写真はもう動いていて取り消せない
    @Test("非表示にできたあとで保存に失敗しても、実行されたものとして扱う")
    func saveFailureAfterRemovalStillDone() async {
        let actions = SpyPhotoActionService()
        let state = makeState(dispositions: SpyPhotoDispositionRepository(failsOnSave: true), actions: actions)
        state.beginSelection()

        await state.remove(.hide, [photo("a")])

        #expect(await actions.hiddenIDs == ["a"])
        #expect(!state.didFailToRemove)
        #expect(!state.isSelecting)
    }
}
