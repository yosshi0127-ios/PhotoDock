//
//  Finding+Display.swift
//  PhotoDock
//

import SwiftUI

/// Core の型を画面に出すための言葉と色。Core は表示を知らないのでここに置く。
/// default を書かないので、種類や段階が増えたらここがコンパイルエラーになる。
extension Severity {

    var tint: Color {
        switch self {
        case .caution: .caution
        case .danger: .danger
        }
    }

    var label: String {
        switch self {
        case .caution: "要注意"
        case .danger: "危険"
        }
    }

    var icon: String {
        switch self {
        case .caution: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.octagon.fill"
        }
    }

    /// 写真に重ねる枠の線。色だけに頼らず線種でも段階が分かるようにする
    var strokeStyle: StrokeStyle {
        switch self {
        case .caution: StrokeStyle(lineWidth: 2, dash: [6, 4])
        case .danger: StrokeStyle(lineWidth: 2)
        }
    }
}

extension StoredFinding {
    /// 写真に重ねる枠の色。参考の項目（顔の写り込み）は、下の表の「参考」と同じ控えめな色にする
    var frameTint: Color {
        ScanReportPolicy.referenceKinds.contains(kind) ? .inkSecondary : severity.tint
    }
}

extension [FindingKind] {
    /// 写真詳細の「この写真を渡すと」の文。写っているものが文字か顔かで言い分ける
    var sharingNote: String {
        let hasFace = contains { ScanReportPolicy.referenceKinds.contains($0) }
        let hasText = contains { !ScanReportPolicy.referenceKinds.contains($0) }
        let subject = switch (hasText, hasFace) {
        case (true, true): "文字と顔"
        case (false, true): "顔"
        default: "文字"
        }
        return "送ると、\(subject)はそのまま残ります"
    }
}

extension FindingKind {

    /// 項目の一覧の上に出す補足。**名前で分かる項目には付けない**。
    /// 顔だけは、文字と違って推定であることを言う（言わないと、44枚が全部「写り込み」と読める）
    var itemNote: String? {
        switch self {
        case .bystanderFace: "形からの推定です"
        case .cardNumber, .identityDocumentNumber, .credential, .phoneNumber, .email, .postalCode, .address: nil
        }
    }

    var label: String {
        switch self {
        case .cardNumber: "カード番号"
        case .identityDocumentNumber: "身分証の番号"
        case .credential: "パスワード・認証情報"
        case .phoneNumber: "電話番号"
        case .email: "メールアドレス"
        case .postalCode: "郵便番号"
        case .address: "住所"
        case .bystanderFace: "顔の写り込み"
        }
    }
}
