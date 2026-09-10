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
        case .caution: .orange
        case .danger: .red
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

extension FindingKind {

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
