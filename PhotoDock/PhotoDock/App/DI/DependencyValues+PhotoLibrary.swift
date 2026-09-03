//
//  DependencyValues+PhotoLibrary.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/03.
//

import Dependencies

private enum PhotoLibraryServiceKey: DependencyKey {
    static let liveValue: any PhotoLibraryService = PhotoKitPhotoLibraryService()
    static let previewValue: any PhotoLibraryService = StubPhotoLibraryService()
    static let testValue: any PhotoLibraryService = UnimplementedPhotoLibraryService()
}

extension DependencyValues {
    var photoLibrary: any PhotoLibraryService {
        get { self[PhotoLibraryServiceKey.self] }
        set { self[PhotoLibraryServiceKey.self] = newValue }
    }
}
