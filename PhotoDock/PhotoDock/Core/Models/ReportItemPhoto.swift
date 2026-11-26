//
//  ReportItemPhoto.swift
//  PhotoDock
//

import Foundation

/// 結果票の項目（種類）を開いたときの、写真1枚ぶんの行。
/// 記録（どこに何が写っているか）に、写真の側の情報（撮った日）を合わせたもの
struct ReportItemPhoto: Sendable, Equatable, Identifiable {
    /// この写真の記録。写真詳細はこれをそのまま表示する
    let record: ScanRecord
    /// 撮った日。写真が持っていなければ nil
    let takenAt: Date?
    /// 開いている項目での、この写真の判定（その種類の所見のうち最も高い段階）
    let verdict: ScanReport.Verdict
    /// この写真に写っている種類。結果票の表と同じ順で、開いている項目自身も含む。
    /// 「住所の写真」に電話番号も写っていることを、一覧の時点で見せるため
    let kinds: [FindingKind]

    var id: String { record.assetID }
}
