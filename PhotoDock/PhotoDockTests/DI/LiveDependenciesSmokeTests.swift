//
//  LiveDependenciesSmokeTests.swift
//  PhotoDockTests
//

import Dependencies
import Testing
@testable import PhotoDock

/// live 登録の煙感知器。
///
/// `previewValue` / `testValue` は Preview とテストが毎回踏むので壊れれば気づくが、
/// **`liveValue` はテストでは踏まれない**。そのため「live にうっかり Stub/Unimplemented を
/// 登録した」事故は誰も検知できない。ここで全 liveValue を解決し、
/// 「解決できる」と「実装が本番用である」の2点だけを固定する。
///
/// 静的な検査（liveValue の右辺が Stub/Noop/Unimplemented でないこと）は `scripts/arch-check.sh` が持つ。
struct LiveDependenciesSmokeTests {
    @Test("全 liveValue（3点）が解決でき、本番実装が入っている")
    func resolvesAllLiveValues() {
        var values = DependencyValues()
        values.context = .live

        #expect(values.photoLibrary is PhotoKitPhotoLibraryService)
        #expect(values.pixelSource is PhotoKitPixelSourceService)
        #expect(values.ocr is VisionOCRService)
    }
}
