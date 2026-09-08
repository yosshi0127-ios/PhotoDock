//
//  FindingKind.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/08.
//

enum FindingKind: Sendable, Equatable, Hashable, CaseIterable {
    /// カード番号（Luhn チェックが通ったもの）
    case cardNumber
    /// マイナンバー・免許証番号（チェックデジットあり）・パスポート番号（書式のみ）
    case identityDocumentNumber
    /// パスワード・認証情報。1行内のラベル語（パスワード / KEY / 暗号化キー 等）で拾う
    case credential

    case phoneNumber
    case email
    case postalCode
    /// 都道府県 + 市区町村。看板・広告・地図アプリのスクショにも当たるので誤検出が多い前提
    case address
}
