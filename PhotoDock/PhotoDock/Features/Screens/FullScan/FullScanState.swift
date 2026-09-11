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
        case finished(ScanSummary)
    }

    private(set) var phase: Phase = .idle
    private(set) var total = 0

    /// 所見があった写真の記録だけを溜める。3万枚でも該当は多くて数千件なのでメモリに乗る。
    /// 記録から復元した分（前回の結果）と、今回診断した分が同じ形で並ぶ
    private(set) var flagged: [ScanRecord] = []

    /// 開始からの経過秒。スキャン中も伸びる
    private(set) var elapsedSeconds: Double = 0

    private let scanLibraryPhotos = ScanLibraryPhotosUseCase()
    private let policy = ScanSummaryPolicy()

    /// 画面に入ったときの自動開始。一度走らせていれば何もしない。
    /// .task は画面に戻るたびに走るので、これを分けないと
    /// 一覧から戻ってくるたびに診断が始まってしまう
    func startIfNeeded(assets: [AssetMetadata], quality: ScanQuality) async {
        guard case .idle = phase else { return }
        await run(assets: assets, quality: quality)
    }

    /// 明示的な再診断。半年に一度回すアプリなので、走り直しは普通の操作
    func restart(assets: [AssetMetadata], quality: ScanQuality) async {
        if case .scanning = phase { return }
        await run(assets: assets, quality: quality)
    }

    private func run(assets: [AssetMetadata], quality: ScanQuality) async {
        total = assets.count
        flagged = []   // 再診断で前回の結果を残さない
        elapsedSeconds = 0
        var summary = ScanSummary.empty
        phase = .scanning(summary)

        let start = ContinuousClock.now

        for await record in scanLibraryPhotos(assets: assets, quality: quality) {
            summary = policy.adding(record, to: summary)
            if record.isFlagged { flagged.append(record) }
            elapsedSeconds = Self.seconds(since: start)
            phase = .scanning(summary)
        }

        elapsedSeconds = Self.seconds(since: start)
        phase = .finished(summary)
    }

    /// components は (seconds, attoseconds) の組で、attoseconds は1秒未満の端数しか
    /// 持たない。整数部を足さないと「75秒」が「0.03秒」になる
    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
}
