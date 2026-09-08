//
//  ScanHomeState.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/07.
//

import Observation

@MainActor
@Observable
final class ScanHomeState {
    
    enum Phase: Equatable {
        case idle
        case scanning
        case loaded(LibraryScanOutcome)
    }
    
    private(set) var phase: Phase = .idle
    
    // 依存は UseCase 経由のみ
    private let scanLibrary = ScanLibraryMetadataUseCase()
    
    func startScan() async {
        guard phase == .idle else { return }
        
        phase = .scanning
        let outcome = await scanLibrary()
        phase = .loaded(outcome)
    }
    
}
