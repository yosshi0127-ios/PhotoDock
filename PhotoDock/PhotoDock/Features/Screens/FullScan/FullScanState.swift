//
//  FullScanState.swift
//  PhotoDock
//

import Foundation
import Observation

/// 全量スキャンの画面状態。診断しながら結果票（`ScanReport`）を1件ずつ埋めていく
@MainActor
@Observable
final class FullScanState {

    enum Phase: Equatable {
        case idle
        case scanning(ScanReport)
        /// 全件流れ切る前に止まった（画面の「中断する」・OS の打ち切り・Live Activity からの中止）。
        /// 記録は残っているので、続きは restart でよい（記録がある分は一瞬で流れる）
        case interrupted(ScanReport)
        case finished(ScanReport)
    }

    private(set) var phase: Phase = .idle
    private(set) var total = 0

    /// 診断の対象。項目を開いたときに、撮った日を引くために持っておく
    private var assets: [AssetMetadata] = []

    /// 所見があった写真の記録だけを溜める。3万枚でも該当は多くて数千件なのでメモリに乗る。
    /// 記録から復元した分（前回の結果）と、今回診断した分が同じ形で並ぶ。
    /// 順序に意味は持たせない（一覧に出すときの並びは Policy が決める）
    private(set) var flagged: [ScanRecord] = []

    /// ここまでに流れてきた記録のすべて。対応が変わったときに、結果票を作り直すために持つ
    /// （3万枚でも、本文を持たない記録なので数MB）
    private var records: [ScanRecord] = []

    /// この画面を開いたあとに、非表示・削除した写真
    private var removedIDs: Set<String> = []

    /// 診断の対象のうち、いまもライブラリにある写真
    private var presentAssets: [AssetMetadata] {
        removedIDs.isEmpty ? assets : assets.filter { !removedIDs.contains($0.id) }
    }

    /// ユーザーが選んだ対応。診断を始めるときに読み、写真詳細で付け外ししたら読み直す
    private var dispositions: [PhotoDisposition] = []

    /// 開始からの経過秒。スキャン中も伸びる
    private(set) var elapsedSeconds: Double = 0

    /// 残りの見積もり（秒）。まだ見積もれないあいだと、診断していないあいだは nil
    private(set) var remainingSeconds: Double?

    /// ここまでの結果票。始める前は全項目が空
    var report: ScanReport {
        switch phase {
        case .idle: reportPolicy.empty
        case let .scanning(report), let .interrupted(report), let .finished(report): report
        }
    }

    /// これから実際に診断する見込みの枚数。中断して再開したときは、診断し終えたぶんを引いてある
    private var expectedToDiagnose = 0

    /// 結果票の項目を開いたときに並べる写真。診断中は、その時点までに見つかった分
    func photos(of kind: FindingKind) -> [ReportItemPhoto] {
        reportPolicy.photos(of: kind, in: flagged, assets: presentAssets, dispositions: dispositions)
    }

    /// その項目で、非表示・削除した写真（対応済みの側に並べる）
    func removedPhotos(of kind: FindingKind) -> [ReportRemovedPhoto] {
        reportPolicy.removedPhotos(
            of: kind, dispositions: dispositions, presentAssetIDs: Set(presentAssets.map(\.id))
        )
    }

    /// ここまでの結果票の、その項目の行（判定と枚数）
    func item(of kind: FindingKind) -> ScanReport.Item? {
        report.items.first { $0.kind == kind }
    }

    private let scanLibraryPhotos = ScanLibraryPhotosUseCase()
    private let loadDispositions = LoadPhotoDispositionsUseCase()
    private let reportPolicy = ScanReportPolicy()
    private let progressPolicy = ScanProgressPolicy()

    /// 走っている診断。View の .task に乗せず自前で持つ。
    /// NavigationStack で子画面（写真詳細）を push すると親の .task はキャンセルされるので、
    /// それに乗せると詳細を開いた瞬間に診断が止まる
    private var scanTask: Task<Void, Never>?

    /// 画面を閉じて State が捨てられたら、走っている診断も止める。
    /// 普通の deinit は nonisolated なので MainActor の scanTask に触れない → isolated deinit（Swift 6.1 / iOS 18.4+）
    isolated deinit {
        scanTask?.cancel()
    }

    /// 画面に入ったときの自動開始。一度走らせていれば何もしない。
    /// onAppear は画面に戻るたびに走るので、これを分けないと
    /// 一覧から戻ってくるたびに診断が始まってしまう。
    /// 同期で返す: View がここを await すると State を掴み続け、画面を閉じても捨てられなくなる。
    ///
    /// expectedToDiagnose は実際に診断する見込みの枚数（残り時間の見積もり用）。
    /// 分からなければ nil でよく、そのときは全件を診断する前提で見積もる
    func startIfNeeded(
        assets: [AssetMetadata],
        quality: ScanQuality,
        allowsDownload: Bool = false,
        expectedToDiagnose: Int? = nil
    ) {
        guard case .idle = phase else { return }
        self.expectedToDiagnose = expectedToDiagnose ?? assets.count
        launch(assets: assets, quality: quality, allowsDownload: allowsDownload)
    }

    /// 中断後の「続きを診断する」。記録がある分は診断せずに流れるので、実際に続きから走る
    func restart(assets: [AssetMetadata], quality: ScanQuality, allowsDownload: Bool = false) {
        if case .scanning = phase { return }
        launch(assets: assets, quality: quality, allowsDownload: allowsDownload)
    }

    /// 写真詳細で対応を付け外ししたあとに呼ぶ。対応を読み直して、ここまでの結果票を作り直す
    func reloadDispositions() async {
        let known = Set(dispositions.map(\.assetID))
        dispositions = await loadDispositions()
        // この画面を開いたあとに非表示・削除した写真。診断の対象の一覧（assets）は開始時点のものなので、
        // ここで外す（外さないと、もう無い写真が未対応として残る）
        removedIDs.formUnion(
            dispositions.filter { $0.action != .dismissed && !known.contains($0.assetID) }.map(\.assetID)
        )
        let rebuilt = reportPolicy.report(
            from: records, presentAssetIDs: Set(presentAssets.map(\.id)), dispositions: dispositions
        )
        switch phase {
        case .idle: break
        case .scanning: phase = .scanning(rebuilt)
        case .interrupted: phase = .interrupted(rebuilt)
        case .finished: phase = .finished(rebuilt)
        }
    }

    /// 画面の「中断する」。走っている診断を止める。
    /// 止まったあとの表示（interrupted）は、診断の Task が流れ終わったところで切り替わる
    func stop() {
        guard case .scanning = phase else { return }
        scanTask?.cancel()
    }

    /// 診断が終わる（完了か中断）まで待つ。テストと、終わりを待ちたい呼び手のため
    func waitUntilSettled() async {
        await scanTask?.value
    }

    private func launch(assets: [AssetMetadata], quality: ScanQuality, allowsDownload: Bool) {
        total = assets.count
        self.assets = assets
        flagged = []   // 再診断で前回の結果を残さない
        self.records = []
        removedIDs = []
        elapsedSeconds = 0
        remainingSeconds = nil
        phase = .scanning(reportPolicy.empty)

        let records = scanLibraryPhotos(assets: assets, quality: quality, allowsDownload: allowsDownload)
        scanTask = Task { [weak self, progressPolicy, loadDispositions] in
            var progress = Progress()
            // 対応済みの写真を、診断中の結果票でも要確認に数えないため
            let dispositions = await loadDispositions()
            self?.dispositions = dispositions

            for await record in records {
                // Task が self を強く持つと画面を閉じても State が捨てられず deinit が来ない。
                // 弱参照にして、消えていたらここで止める（deinit の cancel が先に効くのが普通で、これは保険）
                guard let self else { return }
                // 今回診断した記録は、開始より後の日時を持つ。再利用した記録は前回の日時のまま。
                // そのうち、画像を読むところまで進んだものだけを数える（端末に無い写真は一瞬で終わる）
                if record.scannedAt >= progress.startedAt, progressPolicy.takesTime(record.outcome) {
                    progress.diagnosedNow += 1
                }
                show(record, progress: progress)
            }

            self?.settle(progress)
        }
    }

    /// 診断の Task の中で持ち回る途中経過
    private struct Progress {
        /// 今回の診断で実際に診断した枚数（記録の再利用と、端末に無い写真を除く）。残り時間の見積もりに使う
        var diagnosedNow = 0
        let startedAt = Date.now
        let clockStart = ContinuousClock.now

        /// components は (seconds, attoseconds) の組で、attoseconds は1秒未満の端数しか
        /// 持たない。整数部を足さないと「75秒」が「0.03秒」になる
        var elapsedSeconds: Double {
            let elapsed = clockStart.duration(to: .now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
    }

    private func show(_ record: ScanRecord, progress: Progress) {
        records.append(record)
        if record.isFlagged { flagged.append(record) }
        // 結果票は、いま画面に出ているもの（対応を読み直して作り直したあとなら、その結果）に足していく
        let isHandled = dispositions.first { $0.assetID == record.assetID }.map {
            reportPolicy.isActive($0, modificationDate: record.modificationDate, isPresent: true)
        } ?? false
        let next = reportPolicy.adding(record, to: report, isHandled: isHandled)
        elapsedSeconds = progress.elapsedSeconds
        let remaining = total - next.total
        // 見込みが外れても（端末から消えた・新しく来た）、まだ結果の出ていない枚数は超えない
        let toDiagnose = max(0, min(expectedToDiagnose - progress.diagnosedNow, remaining))
        remainingSeconds = progressPolicy.remainingSeconds(
            diagnosedNow: progress.diagnosedNow,
            remainingToDiagnose: toDiagnose,
            remainingQuick: remaining - toDiagnose,
            elapsedSeconds: elapsedSeconds
        )
        phase = .scanning(next)
    }

    private func settle(_ progress: Progress) {
        elapsedSeconds = progress.elapsedSeconds
        remainingSeconds = nil
        // 中断して再開するときのために、診断し終えたぶんを見込みから引いておく
        expectedToDiagnose = max(0, expectedToDiagnose - progress.diagnosedNow)
        // 全件分の記録が流れていなければ途中で止まっている。止まった理由はここでは分からなくてよく、
        // 「残りがある」ことだけを伝える（完了として途中の数字を見せない）
        let settled = report
        phase = settled.total < total ? .interrupted(settled) : .finished(settled)
    }
}
