//
//  StubPhotoLibraryService.swift
//  PhotoDock
//

import Foundation

/// Preview 用の偽の写真ライブラリ。PhotoKit には触らない。
/// 返す値は完全に決定的（乱数・現在時刻を使わない）。Preview の表示が変わる原因を自分の変更だけに絞るため。
struct StubPhotoLibraryService: PhotoLibraryService {
    func currentAccess() async -> PhotoLibraryAccess {
        .full
    }

    func requestAccess() async -> PhotoLibraryAccess {
        .full
    }

    func fetchAllAssetMetadata() async -> [AssetMetadata] {
        // i が小さいほど新しい = 撮影日時の降順（契約どおりの並び）
        (0..<Fixture.total).map { index in
            let created = Fixture.baseDate.addingTimeInterval(-Fixture.interval * Double(index))
            return AssetMetadata(
                id: "stub-\(index)",
                creationDate: created,
                // 50枚に1枚だけ「後から編集された」写真にする（所見の無効化を Preview で見るため）
                modificationDate: index % 50 == 0 ? created.addingTimeInterval(86_400) : created,
                coordinate: Self.coordinate(at: index),
                isScreenshot: Self.isScreenshot(at: index)
            )
        }
    }

    /// 5枚に2枚をスクリーンショットにする（1,240枚中 496枚）
    private static func isScreenshot(at index: Int) -> Bool {
        index % 5 == 0 || index % 5 == 3
    }

    /// 4枚に1枚へ位置情報を付ける（1,240枚中 310枚）。
    /// うち 248枚を同じ地点に集めて残り 62枚を散らす — 密集地の推定を Preview で確認できるように。
    private static func coordinate(at index: Int) -> GeoCoordinate? {
        guard index % 4 == 1 else { return nil }
        guard index % 20 == 5 else { return Fixture.home }
        return Fixture.spots[(index / 20) % Fixture.spots.count]
    }

    private enum Fixture {
        static let total = 1_240
        /// 固定の基準時刻（2023-11-14 22:13:20 UTC）
        static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        /// 1枚ごとに遡る間隔（8時間 × 1,240枚 ≒ 413日分）
        static let interval: TimeInterval = 8 * 60 * 60
        /// 密集地（自宅のつもり）
        static let home = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)
        /// 散らす先
        static let spots = [
            GeoCoordinate(latitude: 35.658034, longitude: 139.701636),
            GeoCoordinate(latitude: 34.702485, longitude: 135.495951),
            GeoCoordinate(latitude: 43.068564, longitude: 141.350755)
        ]
    }
}
