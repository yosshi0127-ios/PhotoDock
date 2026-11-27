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

    private func makeState(
        dispositions: SpyPhotoDispositionRepository,
        actions: SpyPhotoActionService = SpyPhotoActionService()
    ) -> PhotoDetailState {
        withDependencies {
            $0.photoDispositions = dispositions
            $0.photoActions = actions
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

    // MARK: - 非表示・削除

    @Test("非表示にできたら、非表示にした状態になる")
    func removeHide() async {
        let actions = SpyPhotoActionService()
        let state = makeState(dispositions: SpyPhotoDispositionRepository(), actions: actions)

        await state.remove(.hide, record: record)

        #expect(state.removal == .hide)
        #expect(!state.didFailToRemove)
        #expect(!state.isWorking)
        #expect(await actions.hiddenIDs == ["a"])
    }

    /// iOS の確認で「許可しない」を選んだだけ。失敗の文言を出すと、何か壊れたように見える
    @Test("やめたら、何も変えず、失敗も出さない")
    func removeCancelled() async {
        let state = makeState(
            dispositions: SpyPhotoDispositionRepository(), actions: SpyPhotoActionService(outcome: .cancelled)
        )

        await state.remove(.delete, record: record)

        #expect(state.removal == nil)
        #expect(!state.didFailToRemove)
    }

    @Test("できなかったら、失敗を出す", arguments: [PhotoActionOutcome.notFound, .failed])
    func removeFailed(_ outcome: PhotoActionOutcome) async {
        let state = makeState(
            dispositions: SpyPhotoDispositionRepository(), actions: SpyPhotoActionService(outcome: outcome)
        )

        await state.remove(.hide, record: record)

        #expect(state.removal == nil)
        #expect(state.didFailToRemove)
    }

    /// 非表示にした写真を、続けて削除しようとしても、もうアプリからは見えない
    @Test("一度非表示・削除したら、同じ画面からは続けて操作しない")
    func removeOnlyOnce() async {
        let actions = SpyPhotoActionService()
        let state = makeState(dispositions: SpyPhotoDispositionRepository(), actions: actions)

        await state.remove(.hide, record: record)
        await state.remove(.delete, record: record)

        #expect(state.removal == .hide)
        #expect(await actions.deletedIDs.isEmpty)
    }

    // MARK: - 開いた元の画面の作り直し

    /// 実機で、対応を変えた直後の1〜2秒、戻るボタンを押しても効かなかった。その間は戻る操作を出さない
    @Test("対応を変えてから、開いた元の画面の作り直しが終わるまで、作り直し中になる")
    func refreshingCoversChangeAndRefresh() async {
        let state = makeState(dispositions: SpyPhotoDispositionRepository())
        var seenDuringChange = false
        var seenDuringRefresh = false

        await state.perform({
            seenDuringChange = state.isRefreshing
            await state.dismiss(record: record)
        }, thenRefresh: {
            seenDuringRefresh = state.isRefreshing
        })

        #expect(seenDuringChange)
        #expect(seenDuringRefresh)
        #expect(!state.isRefreshing)
        #expect(state.isDismissed)
    }
}
