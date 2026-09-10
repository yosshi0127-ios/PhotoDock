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

    /// 他人の顔の写り込み。文字ではなく顔検出から来る唯一の種類。
    /// 誰の顔かは分からないので「小さく・端で・横向き」という幾何で推定する（誤検出前提・要注意どまり）
    case bystanderFace
}
