//
//  ScanHomeState.swift
//  PhotoDock
//

import Observation

/// ホームの状態。開いたときは**今の状態を読むだけ**で、アクセスの確認は出さない。
/// 確認を出すのは、初回の案内でユーザーがボタンを押したときだけ
@MainActor
@Observable
final class ScanHomeState {

    enum Phase: Equatable {
        /// 最初の読み込み中。2回目以降の読み直しでは、前の表示を出したままにする
        case loading
        case loaded(ScanHomeSnapshot)
    }

    private(set) var phase: Phase = .loading

    /// 診断画面を出しているか。View の遷移に結び付ける
    var isScanPresented = false

    /// 次に診断するときの品質。当面は精密のみ（brief「スキャン設定」）
    let quality: ScanQuality = .precise

    // 依存は UseCase 経由のみ
    private let loadHome = LoadScanHomeUseCase()
    private let requestAccess = RequestPhotoAccessUseCase()
    private let reportPolicy = ScanReportPolicy()

    /// 結果票の項目を開いたときに並べる写真。並び順と判定は Policy が決める
    func photos(of kind: FindingKind) -> [ReportItemPhoto] {
        guard case let .loaded(.ready(content)) = phase else { return [] }
        return reportPolicy.photos(of: kind, in: content.flagged, assets: content.assets)
    }

    /// 結果票の、その項目の行（判定と枚数）
    func item(of kind: FindingKind) -> ScanReport.Item? {
        guard case let .loaded(.ready(content)) = phase else { return nil }
        return content.report?.items.first { $0.kind == kind }
    }

    /// ホームが表示されるたびに呼ぶ（診断から戻ったときに結果票を更新するため）
    func load() async {
        phase = .loaded(await loadHome(quality: quality))
    }

    /// 初回の案内のボタン。ここで初めてアクセスを聞き、許可されたらそのまま診断を始める
    func allowAccessAndStartScan() async {
        await requestAccess()
        await load()
        startScan()
    }

    /// 診断画面へ進む。診断できる写真が無ければ何もしない
    func startScan() {
        guard case let .loaded(.ready(content)) = phase, !content.assets.isEmpty else { return }
        isScanPresented = true
    }
}
