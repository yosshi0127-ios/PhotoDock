//
//  ScanLibraryMetadataUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Testing
@testable import PhotoDock

@Suite("ScanLibraryMetadataUseCase")
struct ScanLibraryMetadataUseCaseTests {
    /// スキャンが成立しない権限では、列挙まで進まずに理由を返す。
    /// ここで列挙してしまうと空配列が返り、「写真0枚」と区別できない偽の ✅ になる。
    @Test("スキャンできない権限では列挙せず unavailable を返す",
          arguments: [PhotoLibraryAccess.notDetermined, .denied, .restricted])
    func unavailableAccess(_ access: PhotoLibraryAccess) async {
        let spy = SpyPhotoLibraryService(access: access)

        let outcome = await withDependencies {
            $0.photoLibrary = spy
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanLibraryMetadataUseCase()
            return await useCase()
        }

        #expect(outcome == .unavailable(access))
        #expect(await spy.requestAccessCallCount == 1)
        #expect(await spy.fetchCallCount == 0)
    }

    @Test("full なら集計して scanned を返す")
    func fullAccess() async {
        let assets: [AssetMetadata] = [
            .stub(id: "1", coordinate: .anywhere),
            .stub(id: "2", isScreenshot: true),
            .stub(id: "3")
        ]
        let spy = SpyPhotoLibraryService(access: .full, assets: assets)

        let outcome = await withDependencies {
            $0.photoLibrary = spy
        } operation: {
            let useCase = ScanLibraryMetadataUseCase()
            return await useCase()
        }

        #expect(outcome == .scanned(
            access: .full,
            inventory: LibraryInventory(total: 3, withLocation: 1, screenshots: 1),
            assets: assets
        ))
        #expect(await spy.fetchCallCount == 1)
    }

    /// 集計だけ返して assets を捨てると、第2段が対象リストを取り直すことになる
    @Test("集計だけでなく対象そのものも返す")
    func keepsAssetsForSecondStage() async {
        let assets: [AssetMetadata] = [.stub(id: "1"), .stub(id: "2")]
        let spy = SpyPhotoLibraryService(access: .full, assets: assets)

        let outcome = await withDependencies {
            $0.photoLibrary = spy
        } operation: {
            let useCase = ScanLibraryMetadataUseCase()
            return await useCase()
        }

        guard case let .scanned(_, _, returned) = outcome else {
            Issue.record("scanned を期待した")
            return
        }
        #expect(returned.map(\.id) == ["1", "2"])
    }

    /// limited を弾かないのが方針（一部でも診断する）。
    /// access を結果に残すので、UI 側が「一部だけの結果」と表示できる。
    @Test("limited でもスキャンし、access を結果に残す")
    func limitedAccess() async {
        let spy = SpyPhotoLibraryService(
            access: .limited,
            assets: [.stub(id: "1", isScreenshot: true)]
        )

        let outcome = await withDependencies {
            $0.photoLibrary = spy
        } operation: {
            let useCase = ScanLibraryMetadataUseCase()
            return await useCase()
        }

        #expect(outcome == .scanned(
            access: .limited,
            inventory: LibraryInventory(total: 1, withLocation: 0, screenshots: 1),
            assets: [.stub(id: "1", isScreenshot: true)]
        ))
    }

    @Test("空のライブラリは scanned の0枚として返る（unavailable と混ざらない）")
    func emptyLibrary() async {
        let spy = SpyPhotoLibraryService(access: .full, assets: [])

        let outcome = await withDependencies {
            $0.photoLibrary = spy
        } operation: {
            let useCase = ScanLibraryMetadataUseCase()
            return await useCase()
        }

        #expect(outcome == .scanned(
            access: .full,
            inventory: LibraryInventory(total: 0, withLocation: 0, screenshots: 0),
            assets: []
        ))
    }
}
