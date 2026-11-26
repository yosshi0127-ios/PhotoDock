//
//  LoadScanHomeUseCase.swift
//  PhotoDock
//

import Dependencies
import Foundation

/// ホームを開いたときの状態を読む。**アクセスの確認ダイアログは出さない**
/// （初回は約束を見せてから聞くので、ここで聞いてはいけない）。
///
/// 順序の知識だけを持つ: 許可の状態を読む → 写真の一覧・記録・対応状況を読む → Policy に結果票を作らせる
struct LoadScanHomeUseCase: Sendable {
    @Dependency(\.photoLibrary) private var photoLibrary
    @Dependency(\.scanRecords) private var scanRecords
    @Dependency(\.photoDispositions) private var photoDispositions

    private let reportPolicy = ScanReportPolicy()
    private let recordPolicy = ScanRecordPolicy()

    /// quality は次に診断するときの品質。「まだ診断していない写真」の判定に使う
    func callAsFunction(quality: ScanQuality) async -> ScanHomeSnapshot {
        let access = await photoLibrary.currentAccess()

        switch access {
        case .notDetermined:
            return .needsPermission
        case .denied, .restricted:
            return .unavailable(access)
        case .full, .limited:
            break
        }

        let assets = await photoLibrary.fetchAllAssetMetadata()
        // 読めなければ「記録なし」として扱う（記録はキャッシュ。全件を診断し直せば元に戻る）
        let records = (try? await scanRecords.allRecords()) ?? []
        // 読めなければ「まだ何も対応していない」として出す（対応済みの写真が未対応に見えるが、所見を隠すよりよい）
        let dispositions = (try? await photoDispositions.allDispositions()) ?? []
        let index = Dictionary(records.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })

        let generation = recordPolicy.generation(osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
        // 今ある写真のうち、記録があるもの。写真アプリで消した写真の記録はここで落ちる
        let present = assets.compactMap { index[$0.id] }
        let newPhotoCount = assets.count { asset in
            recordPolicy.isOutdated(record: index[asset.id], asset: asset, quality: quality, generation: generation)
        }

        return .ready(ScanHomeContent(
            access: access,
            assets: assets,
            report: present.isEmpty ? nil : reportPolicy.report(
                from: present, presentAssetIDs: Set(assets.map(\.id)), dispositions: dispositions
            ),
            // assets が新しい順なので、present も新しい順になっている
            flagged: present.filter(\.isFlagged),
            newPhotoCount: newPhotoCount,
            dispositions: dispositions
        ))
    }
}
