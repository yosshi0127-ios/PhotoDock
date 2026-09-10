//
//  ScanLibraryPhotosUseCaseTests.swift
//  PhotoDockTests
//

import Dependencies
import Foundation
import Testing
@testable import PhotoDock

/// 全量スキャン（第2段）。診断の中身は 1枚経路のテストが持つので、
/// ここでは「取りこぼさないこと」と「並列数を守ること」を見る。
@Suite("ScanLibraryPhotosUseCase")
struct ScanLibraryPhotosUseCaseTests {

    private func scanAll(
        ids: [String],
        concurrency: Int,
        pixels: any PixelSourceService,
        ocr: SpyOCRService = SpyOCRService()
    ) async -> [ScannedPhoto] {
        await withDependencies {
            $0.pixelSource = pixels
            $0.ocr = ocr
            $0.faceDetection = SpyFaceDetectionService()
        } operation: {
            // @Dependency は生成時点の context を捕捉するので、必ずこの中で作る
            let useCase = ScanLibraryPhotosUseCase()

            var scanned: [ScannedPhoto] = []
            for await photo in useCase(assetIDs: ids, quality: .quick, concurrency: concurrency) {
                scanned.append(photo)
            }
            return scanned
        }
    }

    @Test("渡した枚数だけ、過不足なく流れる")
    func scansEveryAsset() async {
        let ids = (0..<20).map { "asset-\($0)" }

        let scanned = await scanAll(ids: ids, concurrency: 4, pixels: ConcurrencyProbePixelSourceService())

        #expect(scanned.count == ids.count)
        // 完了順なので入力順とは限らない。取りこぼしと重複だけを見る
        #expect(Set(scanned.map(\.assetID)) == Set(ids))
    }

    /// 並列数の制御は「全部直列」でも「制限を超えて全部同時」でも結果は正しく出る。
    /// 実行の重なり方を測らないと壊れていることに気づけない
    @Test("同時実行数が concurrency を超えない")
    func respectsConcurrencyLimit() async {
        let probe = ConcurrencyProbePixelSourceService(delay: .milliseconds(10))
        let ids = (0..<20).map { "asset-\($0)" }

        _ = await scanAll(ids: ids, concurrency: 3, pixels: probe)

        #expect(await probe.maxConcurrent <= 3)
        // 直列に落ちていないことも確認する（1 なら並列化が効いていない）
        #expect(await probe.maxConcurrent > 1)
    }

    /// 0 を渡すと最初の1枚も走らず、1件も処理しないまま正常終了しかねない
    @Test("concurrency が 0 でも全件処理する", arguments: [0, -1, 1])
    func survivesInvalidConcurrency(_ concurrency: Int) async {
        let ids = (0..<5).map { "asset-\($0)" }

        let scanned = await scanAll(ids: ids, concurrency: concurrency, pixels: ConcurrencyProbePixelSourceService())

        #expect(scanned.count == ids.count)
    }

    @Test("空のライブラリでは何も流れずに終わる")
    func emptyLibraryFinishes() async {
        let scanned = await scanAll(ids: [], concurrency: 4, pixels: ConcurrencyProbePixelSourceService())

        #expect(scanned.isEmpty)
    }

    /// 1枚の失敗で全体を止めない。iCloud 上の写真も結果として流す
    @Test("取得できない写真も結果として流れる")
    func reportsUnavailablePhotos() async {
        let ids = (0..<5).map { "asset-\($0)" }
        let pixels = ConcurrencyProbePixelSourceService(outcome: .notAvailableLocally)

        let scanned = await scanAll(ids: ids, concurrency: 2, pixels: pixels)

        #expect(scanned.count == ids.count)
        #expect(scanned.allSatisfy { $0.outcome == .notAvailableLocally })
    }

    /// 消費側がやめても裏で走り続けると、画面を閉じた後も3万枚を処理してしまう
    @Test("途中でやめたら残りはスキャンされない")
    func cancellationStopsScanning() async throws {
        let probe = ConcurrencyProbePixelSourceService(delay: .milliseconds(20))
        let ids = (0..<200).map { "asset-\($0)" }

        await withDependencies {
            $0.pixelSource = probe
            $0.ocr = SpyOCRService()
            $0.faceDetection = SpyFaceDetectionService()
        } operation: {
            let useCase = ScanLibraryPhotosUseCase()

            var count = 0
            for await _ in useCase(assetIDs: ids, quality: .quick, concurrency: 2) {
                count += 1
                if count == 5 { break }
            }
        }

        // 何枚目で止まるかはタイミング次第なので、件数ではなく「止まったこと」を見る
        try await Task.sleep(for: .milliseconds(200))
        let afterLeaving = await probe.callCount
        try await Task.sleep(for: .milliseconds(200))
        let later = await probe.callCount

        #expect(afterLeaving < ids.count)
        // 待っても増えない = 完全に止まっている
        #expect(afterLeaving == later)
    }
}
