//
//  FullScanState.swift
//  PhotoDock
//

import Observation

/// 全量スキャンの画面状態
@MainActor
@Observable
final class FullScanState {

    enum Phase: Equatable {
        case idle
        case scanning(ScanSummary)
        /// 全件流れ切る前に止まった（OS の打ち切り・Live Activity からの中止）。
        /// 記録は残っているので、続きは restart でよい（記録がある分は一瞬で流れる）
        case interrupted(ScanSummary)
        case finished(ScanSummary)
    }

    private(set) var phase: Phase = .idle
    private(set) var total = 0

    /// 所見があった写真の記録だけを溜める。3万枚でも該当は多くて数千件なのでメモリに乗る。
    /// 記録から復元した分（前回の結果）と、今回診断した分が同じ形で並ぶ。**新しいものが先頭**
    private(set) var flagged: [ScanRecord] = []

    /// 開始からの経過秒。スキャン中も伸びる
    private(set) var elapsedSeconds: Double = 0

    private let scanLibraryPhotos = ScanLibraryPhotosUseCase()
    private let policy = ScanSummaryPolicy()

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
    /// 同期で返す: View がここを await すると State を掴み続け、画面を閉じても捨てられなくなる
    func startIfNeeded(assets: [AssetMetadata], quality: ScanQuality, allowsDownload: Bool = false) {
        guard case .idle = phase else { return }
        launch(assets: assets, quality: quality, allowsDownload: allowsDownload)
    }

    /// 明示的な再診断。半年に一度回すアプリなので、走り直しは普通の操作。
    /// 中断後の「続きを診断」もこれ（記録がある分は診断せずに流れる）
    func restart(assets: [AssetMetadata], quality: ScanQuality, allowsDownload: Bool = false) {
        if case .scanning = phase { return }
        launch(assets: assets, quality: quality, allowsDownload: allowsDownload)
    }

    /// 診断が終わる（完了か中断）まで待つ。テストと、終わりを待ちたい呼び手のため
    func waitUntilSettled() async {
        await scanTask?.value
    }

    private func launch(assets: [AssetMetadata], quality: ScanQuality, allowsDownload: Bool) {
        total = assets.count
        flagged = []   // 再診断で前回の結果を残さない
        elapsedSeconds = 0
        phase = .scanning(.empty)

        let records = scanLibraryPhotos(assets: assets, quality: quality, allowsDownload: allowsDownload)
        scanTask = Task { [weak self, policy] in
            let start = ContinuousClock.now
            var summary = ScanSummary.empty

            for await record in records {
                // Task が self を強く持つと画面を閉じても State が捨てられず deinit が来ない。
                // 弱参照にして、消えていたらここで止める（deinit の cancel が先に効くのが普通で、これは保険）
                guard let self else { return }
                summary = policy.adding(record, to: summary)
                show(record, summary: summary, since: start)
            }

            self?.settle(summary, since: start)
        }
    }

    private func show(_ record: ScanRecord, summary: ScanSummary, since start: ContinuousClock.Instant) {
        // 新しいものを先頭に。固定した進捗の直下に現れるので、診断中に目で追える
        if record.isFlagged { flagged.insert(record, at: 0) }
        elapsedSeconds = Self.seconds(since: start)
        phase = .scanning(summary)
    }

    private func settle(_ summary: ScanSummary, since start: ContinuousClock.Instant) {
        elapsedSeconds = Self.seconds(since: start)
        // 全件分の記録が流れていなければ途中で止まっている。止まった理由はここでは分からなくてよく、
        // 「残りがある」ことだけを伝える（完了として途中の数字を見せない）
        phase = summary.completed < total ? .interrupted(summary) : .finished(summary)
    }

    /// components は (seconds, attoseconds) の組で、attoseconds は1秒未満の端数しか
    /// 持たない。整数部を足さないと「75秒」が「0.03秒」になる
    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
}
