//
//  FindingRules.swift
//  PhotoDock
//

/// `FindingPolicy` が使う判定基準。閾値と語彙をここに集約する。
/// 正規表現と判定手順は Policy 側（ここは「何を基準にするか」だけを持つ）。
struct FindingRules: Sendable {
    /// この確度未満の読み取りは誤読とみなし、判定に使わない
    let minimumConfidence: Double

    /// 住所判定に要求する市区町村の文字。都道府県は**要求しない**
    /// （日本の住所は同一都道府県内のやり取りで省略されるのが普通で、名刺・レシート・
    /// 郵便物・申込書はほぼ書かない。必須にすると「渋谷区神南1-2-3」が落ちる）
    let municipalityMarkers: Set<Character>

    /// 認証情報のラベル語（小文字で保持し、比較時に入力も小文字化する）。順序 = 優先度。
    /// Set にしないこと: 反復順序がプロセスごとに変わるため、複数一致した行の
    /// マスク結果が実行ごとに変わってしまう。
    /// 短い一般語を入れてはいけない: 小文字で部分一致するため "pin" は "shopping" に当たる
    let credentialLabels: [String]

    /// Luhn を適用する桁数の範囲（区切り記号を除去した後）
    let cardNumberDigits: ClosedRange<Int>

    /// マスクで末尾に残す桁数
    let maskedTrailingDigits: Int

    static let standard = FindingRules(
        minimumConfidence: 0.5,
        municipalityMarkers: ["市", "区", "町", "村"],
        credentialLabels: [
            "パスワード", "パスコード", "暗証番号", "暗号化キー", "認証コード", "password"
        ],
        cardNumberDigits: 13...19,
        maskedTrailingDigits: 4
    )
}
