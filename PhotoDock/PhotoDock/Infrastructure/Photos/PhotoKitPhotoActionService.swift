//
//  PhotoKitPhotoActionService.swift
//  PhotoDock
//

import Photos

/// PhotoKit による非表示・削除。
///
/// 実機で確かめた挙動（iPhone 15 Pro Max・2026-11-26。brief「段階3で決めたこと」）:
/// - どちらも `performChanges` の中で OS が確認を出し、答えが出るまで戻らない
/// - 「許可しない」は `PHPhotosError.userCancelled`（3072）
/// - 非表示にした写真は、以後 `includeHiddenAssets` を指定しても取れない
struct PhotoKitPhotoActionService: PhotoActionService {
    func hide(assetIDs: [String]) async -> PhotoActionOutcome {
        let assets = Self.assets(assetIDs)
        guard !assets.isEmpty else { return .notFound }
        do {
            // 1回の変更にまとめる（OS の確認が、まとめて1回になる）
            try await PHPhotoLibrary.shared().performChanges {
                for asset in assets {
                    PHAssetChangeRequest(for: asset).isHidden = true
                }
            }
            return .done
        } catch {
            return Self.outcome(for: error)
        }
    }

    func delete(assetIDs: [String]) async -> PhotoActionOutcome {
        let assets = Self.assets(assetIDs)
        guard !assets.isEmpty else { return .notFound }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return .done
        } catch {
            return Self.outcome(for: error)
        }
    }

    private static func assets(_ ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        return (0..<result.count).map { result.object(at: $0) }
    }

    private static func outcome(for error: any Error) -> PhotoActionOutcome {
        (error as? PHPhotosError)?.code == .userCancelled ? .cancelled : .failed
    }
}
