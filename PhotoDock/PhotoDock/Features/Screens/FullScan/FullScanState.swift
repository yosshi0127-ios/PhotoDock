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
    
    private let scanLibraryPhotos = ScanLibraryPhotosUseCase()
    private let policy = ScanSummaryPolicy()
    
    /// 走行中の二重起動だけ弾く。終わったあとは「もう一度診断」で走り直せる
    /// （半年に一度回すアプリなので、再診断は普通の操作）
    func start(assetIDs: [String], quality: ScanQuality) async {
        if case .scanning = phase { return }
        
        total = assetIDs.count
        var summary = ScanSummary.empty
        phase = .scanning(summary)
        
        for await photo in scanLibraryPhotos(assetIDs: assetIDs, quality: quality) {
            summary = policy.adding(photo, to: summary)
            phase = .scanning(summary)
        }
        
        phase = .finished(summary)
    }
}
