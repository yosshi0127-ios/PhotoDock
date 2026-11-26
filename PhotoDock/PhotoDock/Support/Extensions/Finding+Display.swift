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

extension FindingKind {

    /// 項目の一覧の上に出す一言。どんな写真が当てはまるかを、身近な例で言う
    var itemNote: String {
        switch self {
        case .cardNumber: "カードそのものの写真や、番号を写したメモなどです。"
        case .identityDocumentNumber: "パスポートなど、身分証の番号が読める写真です。"
        case .credential: "Wi-Fi のメモやログイン画面など、パスワードや認証コードが読める写真です。"
        case .phoneNumber: "名刺や書類、連絡先の画面などです。"
        case .email: "名刺やメールの画面などです。"
        case .postalCode: "宛名ラベルや書類などです。住所と一緒に写っていることが多い項目です。"
        case .address: "宛名ラベルや名刺、書類などです。"
        case .bystanderFace: "小さく写った顔や、端にある顔、横を向いた顔です。写り込みかどうかは形だけで推定しているので、参考として出しています。"
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
