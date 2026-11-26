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
    func hide(assetID: String) async -> PhotoActionOutcome {
        guard let asset = Self.asset(assetID) else { return .notFound }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).isHidden = true
            }
            return .done
        } catch {
            return Self.outcome(for: error)
        }
    }

    func delete(assetID: String) async -> PhotoActionOutcome {
        guard let asset = Self.asset(assetID) else { return .notFound }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            return .done
        } catch {
            return Self.outcome(for: error)
        }
    }

    private static func asset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private static func outcome(for error: any Error) -> PhotoActionOutcome {
        (error as? PHPhotosError)?.code == .userCancelled ? .cancelled : .failed
    }
}
