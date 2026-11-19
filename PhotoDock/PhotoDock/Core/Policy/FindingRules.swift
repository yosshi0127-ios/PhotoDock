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

    /// 番地の数字1つの桁数（`1-2-3` の各部分）。丁目は1〜2桁、番地は多くて4桁
    let addressBlockGroupDigits: ClosedRange<Int>

    /// `1-2-3` の3つを合わせた桁数の上限。`1234-12-1203` で10桁。
    /// これを超える並びは注文番号や通し番号（`1234-5678-9012`）のことが多い
    let addressBlockMaxDigits: Int

    /// 認証情報のラベル語。順序 = 優先度。表示したい表記をそのまま書けばよい
    /// （照合用の正規化は `CredentialLabel` が導出する）。
    /// Set にしないこと: 反復順序がプロセスごとに変わるため、複数一致した行の
    /// マスク結果が実行ごとに変わってしまう。
    /// 短い一般語を入れてはいけない: 部分一致するため "pin" は "shopping" に当たる。
    /// **辞書で網羅することは原理的に不可能**（brief「検出する種類」参照）。
    /// ここに無い語は取りこぼす前提で、値の書式による検出と併用する
    let credentialLabels: [CredentialLabel]

    /// ラベル語の直後に続く文字列を「値」とみなす最小の長さ。4 は暗証番号の桁数
    /// （`暗証番号 1234` を拾い、`Password: On` のような設定値や記号1つを拾わない）
    let credentialValueMinLength: Int

    /// Luhn を適用する桁数の範囲（区切り記号を除去した後）
    let cardNumberDigits: ClosedRange<Int>

    /// カードブランドの番号帯と桁数。Luhn が通り、かつこのどれかに合えば「危険」（断定してよい）。
    /// Visa の13桁は載せない: 発行されなくなって久しく、載せると 45 / 49 で始まる
    /// 13桁の JAN コード（日本の商品バーコードの数字）の1割が偶然カード番号になる
    let cardNumberFormats: [CardNumberFormat]

    /// 番号帯がどのブランドにも合わないとき、この区切り方で書かれていて Luhn が通れば「要注意」。
    /// 表に無いブランドのカードを見逃さないための受け皿（書式の一致だけなので断定しない）
    let unbrandedCardGrouping: [Int]

    /// マスクで末尾に残す桁数
    let maskedTrailingDigits: Int

    // 写り込みらしい顔の判定。**値は仮置き**で、実機のカメラロールで何枚引っかかるかを見て調整する。
    // 誰の顔かは分からないので、「小さく・端で・横向き」という幾何だけで推定する

    /// 面積比（幅 × 高さ、0...1）がこれ未満なら「小さい」。セルフィーは 10% 前後、集合写真の1人は 1% 前後
    let bystanderFaceMaxArea: Double
    /// 画像の縁からこの距離以内に触れていれば「端」
    let bystanderFaceEdgeMargin: Double
    /// |yaw|（ラジアン）がこれ以上なら「横を向いている」。yaw が取れなければこの条件は使わない
    let bystanderFaceMinYaw: Double

    static let standard = FindingRules(
        minimumConfidence: 0.5,
        municipalityMarkers: ["市", "区", "町", "村"],
        addressBlockGroupDigits: 1...4,
        addressBlockMaxDigits: 10,
        credentialLabels: [
            CredentialLabel("パスワード"),
            CredentialLabel("パスコード"),
            CredentialLabel("暗証番号"),
            CredentialLabel("暗号化キー"),
            CredentialLabel("認証コード"),
            CredentialLabel("APIキー"),
            CredentialLabel("アクセストークン"),
            CredentialLabel("秘密鍵"),
            CredentialLabel("リカバリーコード"),
            CredentialLabel("Password"),
            CredentialLabel("API Key"),
            CredentialLabel("Access Token"),
            CredentialLabel("Private Key")
        ],
        credentialValueMinLength: 4,
        cardNumberDigits: 13...19,
        cardNumberFormats: [
            CardNumberFormat(prefixes: [4...4], lengths: [16, 19]),                           // Visa
            CardNumberFormat(prefixes: [51...55, 2221...2720], lengths: [16]),                // Mastercard
            CardNumberFormat(prefixes: [34...34, 37...37], lengths: [15]),                    // American Express
            CardNumberFormat(prefixes: [300...305, 36...36, 38...39], lengths: [14]),         // Diners Club
            CardNumberFormat(prefixes: [3528...3589], lengths: [16]),                         // JCB
            CardNumberFormat(prefixes: [6011...6011, 644...649, 65...65], lengths: [16]),     // Discover
            CardNumberFormat(prefixes: [62...62], lengths: [16, 17, 18, 19])                  // 銀聯
        ],
        unbrandedCardGrouping: [4, 4, 4, 4],
        maskedTrailingDigits: 4,
        bystanderFaceMaxArea: 0.02,
        bystanderFaceEdgeMargin: 0.10,
        bystanderFaceMinYaw: 0.6
    )
}
