//
//  ScanLibraryMetadataUseCase.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

import Dependencies

struct ScanLibraryMetadataUseCase: Sendable {
    
    @Dependency(\.photoLibrary) private var photoLibrary
    
    private let policy = LibraryInventoryPolicy()
    
    func callAsFunction() async -> LibraryScanOutcome {
        let access = await photoLibrary.requestAccess()
        
        switch access {
        case .full, .limited:
            let assets = await photoLibrary.fetchAllAssetMetadata()
            return .scanned(access: access, inventory: policy.inventory(of: assets), assets: assets)
            
        case .notDetermined, .denied, .restricted:
            return .unavailable(access)
        }
        
    }
        
}
