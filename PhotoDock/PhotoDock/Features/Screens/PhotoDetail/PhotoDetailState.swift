//
//  PhotoDetailState.swift
//  PhotoDock
//

import Foundation
import Observation
import UIKit

/// 写真詳細の状態。
/// **記録を表示するだけで診断しない** — 一覧と詳細が同じ記録を見るので食い違わない。
@MainActor
@Observable
final class PhotoDetailState {

    /// 所見の枠を重ねる下地。読み込み中と、読み込めなかったときは nil
    private(set) var image: UIImage?

    /// 写真を読み込んでいる途中か。終わっても image が nil なら、表示できなかった
    private(set) var isLoadingImage = true

    /// 種類ごとにまとめた所見。写真の読み込みを待たずに出す
    private(set) var findings: [ReportPhotoFinding] = []

    /// 「問題なし」にしてあるか。開いたときは一覧の時点の状態で、ボタンを押すと変わる
    private(set) var isDismissed = false

    /// 対応を保存できなかった。次に押して成功するまで出す
    private(set) var didFailToSave = false

    /// この画面で、写真を非表示にした・削除した。写真はもうアプリから見えないので、以後の操作は出さない
    private(set) var removal: RemovePhotoUseCase.Method?

    /// 非表示・削除ができなかった（ユーザーがやめた場合は含めない）
    private(set) var didFailToRemove = false

    /// iOS の確認に答えるのを待っている。その間は、ほかのボタンを押せなくする
    private(set) var isWorking = false

    /// 対応を変えたあと、開いた元の画面（ホーム・診断中の画面）が結果票を作り直している。
    /// **その間は、戻る操作を出さない**。実機（写真 3,000枚）では、作り直しに1〜2秒かかり、
    /// その間に押した「戻る」が効かなかった（押しても何も起きないボタンが見えている状態だった）
    private(set) var isRefreshing = false

    /// 対応を変える操作を、開いた元の画面の作り直しが終わるまでをひとまとまりにして行う
    func perform(_ change: () async -> Void, thenRefresh refresh: () async -> Void) async {
        isRefreshing = true
        defer { isRefreshing = false }
        await change()
        await refresh()
    }

    // 依存は UseCase 経由のみ
    private let loadThumbnail = LoadThumbnailUseCase()
    private let dismissPhoto = DismissPhotoUseCase()
    private let reopenPhoto = ReopenPhotoUseCase()
    private let removePhoto = RemovePhotoUseCase()
    private let reportPolicy = ScanReportPolicy()

    private var didShow = false

    /// 記録をそのまま見せる。
    /// 表示は縮小版で足りる — Region は正規化座標なので、比率が同じなら枠は合う
    func show(record: ScanRecord, isHandled: Bool) async {
        guard !didShow else { return }   // 再表示のたびに読み直さない
        didShow = true
        isDismissed = isHandled

        findings = reportPolicy.findings(in: record)
        image = await loadThumbnail(assetID: record.assetID, maxPixelSize: 1_200).flatMap(UIImage.init(data:))
        isLoadingImage = false
    }

    /// 「問題なしにする」。写真ライブラリには触らず、アプリの中の印を付けるだけ。
    /// 保存できたときだけ表示を変える（できていないのに「対応済み」と見せない）
    func dismiss(record: ScanRecord, takenAt: Date? = nil) async {
        do {
            try await dismissPhoto(record: record, takenAt: takenAt)
            isDismissed = true
            didFailToSave = false
        } catch {
            didFailToSave = true
        }
    }

    /// 「未対応に戻す」
    func reopen(record: ScanRecord) async {
        do {
            try await reopenPhoto(assetID: record.assetID)
            isDismissed = false
            didFailToSave = false
        } catch {
            didFailToSave = true
        }
    }

    /// 「非表示アルバムへ移す」「削除する」。確認は iOS が出す。
    /// 「許可しない」が選ばれたら何も変えない（失敗の文言も出さない）
    func remove(_ method: RemovePhotoUseCase.Method, record: ScanRecord, takenAt: Date? = nil) async {
        guard !isWorking, removal == nil else { return }
        isWorking = true
        defer { isWorking = false }

        switch await removePhoto(method, record: record, takenAt: takenAt) {
        case .done:
            removal = method
            didFailToRemove = false
        case .cancelled:
            didFailToRemove = false
        case .notFound, .failed:
            didFailToRemove = true
        }
    }
}
