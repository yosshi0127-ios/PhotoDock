//
//  FullScanState.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/10.
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

    /// 所見があった写真だけを溜める。3万枚でも該当は多くて数千件なのでメモリに乗る。
    /// アプリを閉じると消える（永続化は所見インデックスの実装で入れる）
    private(set) var flagged: [ScannedPhoto] = []
    
    private let scanLibraryPhotos = ScanLibraryPhotosUseCase()
    private let policy = ScanSummaryPolicy()
    
    /// 画面に入ったときの自動開始。一度走らせていれば何もしない。
    /// .task は画面に戻るたびに走るので、これを分けないと
    /// 一覧から戻ってくるたびに診断が始まってしまう
    func startIfNeeded(assetIDs: [String], quality: ScanQuality) async {
        guard case .idle = phase else { return }
        await run(assetIDs: assetIDs, quality: quality)
    }

    /// 明示的な再診断。半年に一度回すアプリなので、走り直しは普通の操作
    func restart(assetIDs: [String], quality: ScanQuality) async {
        if case .scanning = phase { return }
        await run(assetIDs: assetIDs, quality: quality)
    }

    private func run(assetIDs: [String], quality: ScanQuality) async {
        total = assetIDs.count
        flagged = []   // 再診断で前回の結果を残さない
        var summary = ScanSummary.empty
        phase = .scanning(summary)

        for await photo in scanLibraryPhotos(assetIDs: assetIDs, quality: quality) {
            summary = policy.adding(photo, to: summary)
            if photo.isFlagged { flagged.append(photo) }
            phase = .scanning(summary)
        }
        
        phase = .finished(summary)
    }
}
