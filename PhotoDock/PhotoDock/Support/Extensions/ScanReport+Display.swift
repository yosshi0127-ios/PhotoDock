//
//  ScanReport+Display.swift
//  PhotoDock
//

import SwiftUI

extension ScanReport.Verdict {
    /// 結果票の上の言葉。severity の「要注意」は、検診に合わせて「要確認」と書く
    var label: String {
        switch self {
        case .clear: "所見なし"
        case .caution: "要確認"
        case .danger: "危険"
        case .reference: "参考"
        case .handled: "対応済み"
        }
    }

    var tint: Color {
        switch self {
        case .clear: .themeAccent
        case .caution: .caution
        case .danger: .danger
        case .reference: .inkSecondary
        case .handled: .themeAccent
        }
    }

    /// 対応が必要な判定だけ太くする（色だけに頼らず、太さでも段階が分かるようにする）
    var isEmphasized: Bool {
        switch self {
        case .caution, .danger: true
        case .clear, .reference, .handled: false
        }
    }
}

extension ScanReport.Grade {
    var tint: Color {
        switch self {
        case .a: .themeAccent
        case .b: .caution
        case .c: .danger
        }
    }
}

extension ScanReport {
    /// 総合判定の見出し。枚数は写真の枚数
    var verdictHeadline: String {
        switch grade {
        case .a: "所見なし"
        case .b: "要確認 \(cautionPhotos.formatted()) 枚"
        case .c: "要対応 \(dangerPhotos.formatted()) 枚"
        }
    }

    /// 見出しの下の補足。見出しだけでは分からないことがあるときだけ返す:
    /// 危険のほかに要確認もある／所見なしだが、対応して無くなった
    var verdictNote: String? {
        switch grade {
        case .a where handledPhotos > 0: "対応済み \(handledPhotos.formatted()) 枚"
        case .c where cautionPhotos > 0: "ほか要確認 \(cautionPhotos.formatted()) 枚"
        case .a, .b, .c: nil
        }
    }
}
