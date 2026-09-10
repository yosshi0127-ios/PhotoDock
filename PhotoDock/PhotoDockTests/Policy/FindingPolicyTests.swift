//
//  FindingPolicyTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

/// 判定の境界・ルールの適用順序・マスクの形を固定する。
/// フレームワークを起動しない純粋関数のテストなので、全ケースを網羅しても一瞬で終わる。
@Suite("FindingPolicy")
struct FindingPolicyTests {
    private let sut = FindingPolicy()

    private func kind(of text: String) -> FindingKind? {
        sut.classify(text)?.kind
    }

    // MARK: - カード番号（Luhn）

    @Test("Luhn が通る番号はカード番号として危険")
    func validCardNumber() {
        let match = sut.classify("4111 1111 1111 1111")

        #expect(match?.kind == .cardNumber)
        #expect(match?.severity == .danger)
    }

    @Test("Luhn が通らない番号はカード番号にしない")
    func invalidCardNumberChecksum() {
        // 末尾を 1 桁変えるとチェックサムが合わなくなる
        #expect(kind(of: "4111 1111 1111 1112") != .cardNumber)
    }

    @Test("桁数が範囲外ならカード番号にしない", arguments: [
        "4111 1111 1111",          // 12桁（13未満）
        "4111 1111 1111 1111 111"  // 19桁を超える
    ])
    func cardNumberDigitCount(_ text: String) {
        #expect(kind(of: text) != .cardNumber)
    }

    @Test("ハイフン区切りのカード番号も拾う")
    func cardNumberWithHyphens() {
        #expect(kind(of: "4111-1111-1111-1111") == .cardNumber)
    }

    // MARK: - 認証情報

    @Test("ラベル語がある行は認証情報として危険", arguments: [
        "パスワード: hunter2",
        "暗号化キー AbCd1234",
        "Password: correcthorse",
        "暗証番号 1234",
        "APIキー sk-test-000000000000",
        "アクセストークン ghp_0000000000",
        "秘密鍵 -----BEGIN PRIVATE KEY-----"
    ])
    func credentialLabels(_ text: String) {
        let match = sut.classify(text)

        #expect(match?.kind == .credential)
        #expect(match?.severity == .danger)
    }

    /// ラベル語は電話番号より先に試す。ラベルがあれば意図が明確なので、そちらを採る
    @Test("ラベル語と電話番号が同じ行にあれば認証情報を採る")
    func credentialWinsOverPhoneNumber() {
        #expect(kind(of: "パスワード: 090-1234-5678") == .credential)
    }

    @Test("短い一般語では認証情報にしない（pin は shopping に含まれる）")
    func credentialAvoidsShortWords() {
        #expect(kind(of: "shopping list") == nil)
        #expect(kind(of: "monkey key") == nil)
    }

    /// OCR は「API キー」のように空白込みで返すことがある
    @Test("ラベル語の途中に空白が入っていても拾う")
    func credentialIgnoresWhitespaceInLabel() {
        #expect(kind(of: "API キー sk-test-000000000000") == .credential)
        #expect(kind(of: "access token ghp_0000000000") == .credential)
    }

    /// 辞書は増やさず、正規化で表記の揺れだけを吸収する
    @Test("ラベル語の表記揺れを正規化で吸収する", arguments: [
        "API_KEY abcdefghijklmnop",
        "api-key: abcdefghijklmnop",
        "Ａｐｉ　Ｋｅｙ ABCDEFGHIJKLMNOP",
        "API・キー abcdefghijklmnop"
    ])
    func credentialLabelNormalization(_ text: String) {
        #expect(kind(of: text) == .credential)
    }

    /// 全角は英数だけを半角に寄せる。Foundation の .fullwidthToHalfwidth は
    /// カタカナも半角にするので「パスワード」→「ﾊﾟｽﾜｰﾄﾞ」となり既存ラベルが全滅する
    @Test("正規化してもカタカナのラベルは壊れない")
    func normalizationKeepsKatakana() {
        #expect("パスワード".normalizedForLabelMatch() == "パスワード")
        #expect("API_KEY".normalizedForLabelMatch() == "apikey")
        #expect("Ａｐｉ　Ｋｅｙ".normalizedForLabelMatch() == "apikey")
    }

    /// ラベル辞書は網羅できないので、値の書式が下支えになる。
    /// 機械が発行するトークンはプレフィックスが業界固有で誤検出しにくい
    @Test("機械が発行するトークンはラベルなしでも認証情報", arguments: [
        "sk-proj-abcdefghijklmnopqrstuvwxyz",
        "ghp_abcdefghijklmnopqrstuvwxyz1234",
        "AKIAIOSFODNN7EXAMPLE",
        "xoxb-1234567890-abcdefghij",
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc",
        "-----BEGIN RSA PRIVATE KEY-----"
    ])
    func credentialValuePatterns(_ text: String) {
        let match = sut.classify(text)

        #expect(match?.kind == .credential)
        #expect(match?.severity == .danger)
    }

    // MARK: - 住所

    @Test("市区町村と番地が揃えば住所。都道府県は要求しない", arguments: [
        "東京都渋谷区神南1-2-3",
        "渋谷区神南1-2-3",
        "渋谷区神南1丁目",
        "港区芝公園4番地"
    ])
    func addressVariants(_ text: String) {
        let match = sut.classify(text)

        #expect(match?.kind == .address)
        #expect(match?.severity == .caution)
    }

    @Test("市区町村だけでは住所にしない（看板や施設名を拾わないため）", arguments: [
        "東京都",
        "渋谷区役所",
        "市民ホール"
    ])
    func addressNeedsBlockNumber(_ text: String) {
        #expect(kind(of: text) != .address)
    }

    @Test("時刻の範囲を番地とみなさない")
    func timeRangeIsNotAddress() {
        // 2連の数字を番地として扱うと「30-17」に当たってしまう
        #expect(kind(of: "渋谷区役所 8:30-17:15") != .address)
    }

    @Test("番線のような表示を番地とみなさない")
    func platformNumberIsNotAddress() {
        #expect(kind(of: "新宿区 3番線のりば") != .address)
    }

    // MARK: - 電話番号・郵便番号・メール・パスポート

    @Test("携帯と固定の書式を電話番号として拾う", arguments: [
        "090-1234-5678",
        "08012345678",
        "03-1234-5678",
        "0426-12-3456"
    ])
    func phoneNumbers(_ text: String) {
        #expect(kind(of: text) == .phoneNumber)
    }

    /// 「03-1234-5678」には郵便番号の書式（234-5678）が部分文字列として含まれる。
    /// 電話番号を先に試すことでこれを防いでいる
    @Test("電話番号を郵便番号と誤判定しない")
    func phoneNumberIsNotPostalCode() {
        #expect(kind(of: "03-1234-5678") == .phoneNumber)
    }

    @Test("郵便番号の書式を拾う")
    func postalCode() {
        #expect(kind(of: "〒150-0041") == .postalCode)
    }

    /// 郵便番号と住所が同じ行にあるときは、情報量の多い住所を採る
    @Test("郵便番号より住所を優先する")
    func addressWinsOverPostalCode() {
        #expect(kind(of: "〒150-0041 渋谷区神南1-2-3") == .address)
    }

    @Test("メールアドレスを拾う")
    func email() {
        #expect(kind(of: "連絡先は yamada@example.com です") == .email)
    }

    @Test("パスポート番号の書式は本人確認書類・ただし要注意止まり")
    func passportNumber() {
        let match = sut.classify("AB1234567")

        #expect(match?.kind == .identityDocumentNumber)
        // 書式一致のみでチェックデジットを検証していないので断定しない
        #expect(match?.severity == .caution)
    }

    @Test("何も該当しない行は所見にならない", arguments: [
        "こんにちは",
        "2026年9月8日",
        "合計 1,280円"
    ])
    func noFinding(_ text: String) {
        #expect(kind(of: text) == nil)
    }

    // MARK: - マスク

    @Test("カード番号は末尾4桁だけ残し、区切りは保つ")
    func maskedCardNumber() {
        #expect(sut.masked("4111 1111 1111 1111", as: .cardNumber) == "**** **** **** 1111")
    }

    @Test("電話番号は末尾4桁だけ残す")
    func maskedPhoneNumber() {
        #expect(sut.masked("090-1234-5678", as: .phoneNumber) == "***-****-5678")
    }

    /// 住所は番地を全部伏せる。漢字は残るので「どこの住所か」の識別はできる
    @Test("住所は数字を全部伏せる")
    func maskedAddress() {
        #expect(sut.masked("渋谷区神南1-2-3", as: .address) == "渋谷区神南*-*-*")
    }

    /// Character.isNumber は漢数字にも true を返す。それで伏せると
    /// 「東京都千代田区」が「東*都*代田区」になり、どこの住所か分からなくなる
    @Test("地名の漢数字は伏せない", arguments: [
        ("東京都千代田区霞が関1-1-1", "東京都千代田区霞が関*-*-*"),
        ("三田1-2-3", "三田*-*-*"),
        ("八王子市万町4-5", "八王子市万町*-*")
    ])
    func kanjiNumeralsSurviveMasking(_ input: String, _ expected: String) {
        #expect(sut.masked(input, as: .address) == expected)
    }

    @Test("全角の算用数字は伏せる")
    func fullWidthDigitsAreMasked() {
        #expect(sut.masked("渋谷区神南１-２-３", as: .address) == "渋谷区神南*-*-*")
    }

    /// 下4桁だけで町域が特定できるので、カード番号のように末尾を残さない
    @Test("郵便番号は全桁伏せる")
    func maskedPostalCode() {
        #expect(sut.masked("〒150-0041", as: .postalCode) == "〒***-****")
    }

    /// 桁数を漏らさないため、実際の長さと無関係な固定長にする
    @Test("認証情報はラベル語だけ残して固定長で伏せる")
    func maskedCredential() {
        #expect(sut.masked("パスワード: hunter2", as: .credential) == "パスワード ********")
        #expect(sut.masked("パスワード: aVeryLongPassphrase", as: .credential) == "パスワード ********")
    }

    /// 照合は正規化した形で行うが、表示には元の表記を出す
    @Test("マスクに出るのは照合用の小文字ではなく元の表記")
    func maskedCredentialUsesDisplayForm() {
        #expect(sut.masked("APIキー sk-test-000000000000", as: .credential) == "APIキー ********")
        #expect(sut.masked("api_key: hunter2", as: .credential) == "API Key ********")
    }

    /// 値の書式だけで拾った行にはラベルが無い
    @Test("ラベルの無い認証情報は伏せ字だけを返す")
    func maskedCredentialWithoutLabel() {
        #expect(sut.masked("sk-proj-abcdefghijklmnopqrstuvwxyz", as: .credential) == "********")
    }

    @Test("メールはローカル部の先頭1文字とドメインを残し、周りの文字はそのまま")
    func maskedEmail() {
        #expect(
            sut.masked("連絡先は yamada@example.com です", as: .email)
                == "連絡先は y*****@example.com です"
        )
    }

    // MARK: - 顔の写り込み

    private func face(x: Double, y: Double, width: Double, height: Double, yaw: Double? = nil) -> DetectedFace {
        DetectedFace(region: Region(x: x, y: y, width: width, height: height), yaw: yaw)
    }

    /// セルフィーや家族写真が全部要注意になったら製品として死ぬ
    @Test("大きく中央で正面の顔は所見にしない（撮りたかった人）")
    func subjectFaceIsNotAFinding() {
        let selfie = face(x: 0.3, y: 0.2, width: 0.4, height: 0.3, yaw: 0)

        #expect(!sut.isBystander(selfie))
        #expect(sut.findings(in: [], faces: [selfie]).isEmpty)
    }

    @Test("小さく端にある顔は写り込みとして要注意", arguments: [
        (0.92, 0.40, 0.05, 0.06),   // 右端
        (0.40, 0.02, 0.05, 0.06),   // 上端
        (0.02, 0.50, 0.04, 0.05)    // 左端
    ])
    func smallEdgeFaceIsBystander(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        let findings = sut.findings(in: [], faces: [face(x: x, y: y, width: width, height: height)])

        #expect(findings.map(\.kind) == [.bystanderFace])
        #expect(findings.first?.severity == .caution)
    }

    /// 端でなくても、小さくて横を向いていれば写り込みらしい
    @Test("小さく横を向いた顔は中央でも写り込み")
    func smallTurnedFaceIsBystander() {
        #expect(sut.isBystander(face(x: 0.45, y: 0.45, width: 0.05, height: 0.06, yaw: 0.9)))
    }

    /// yaw を 0 で埋めると「正面だから被写体」に倒れる。分からないなら向きの条件は使わない
    @Test("向きが取れない小さい顔は、端でなければ所見にしない")
    func unknownYawFallsBackToGeometry() {
        #expect(!sut.isBystander(face(x: 0.45, y: 0.45, width: 0.05, height: 0.06, yaw: nil)))
    }

    /// 大きい顔は端にあっても横を向いていても撮りたかった人
    @Test("大きい顔は端で横向きでも所見にしない")
    func largeEdgeFaceIsSubject() {
        #expect(!sut.isBystander(face(x: 0.0, y: 0.1, width: 0.35, height: 0.4, yaw: 0.9)))
    }

    @Test("文字と顔の所見は同じ配列にまとまる")
    func textAndFaceFindingsCombine() {
        let texts = [RecognizedText(text: "4111 1111 1111 1111", confidence: 1, region: .test)]
        let faces = [face(x: 0.92, y: 0.4, width: 0.05, height: 0.06)]

        let kinds = sut.findings(in: texts, faces: faces).map(\.kind)

        #expect(kinds == [.cardNumber, .bystanderFace])
    }

    // MARK: - findings（入口）

    @Test("確度が閾値未満の行は誤読として捨てる")
    func lowConfidenceIsDropped() {
        let texts = [
            RecognizedText(text: "4111 1111 1111 1111", confidence: 0.4, region: .test),
            RecognizedText(text: "090-1234-5678", confidence: 0.9, region: .test)
        ]

        let findings = sut.findings(in: texts)

        #expect(findings.count == 1)
        #expect(findings.first?.kind == .phoneNumber)
    }

    @Test("1行につき所見は最大1件")
    func oneFindingPerLine() {
        let texts = [
            RecognizedText(text: "パスワード: 090-1234-5678", confidence: 1, region: .test)
        ]

        #expect(sut.findings(in: texts).count == 1)
    }

    @Test("所見は認識結果の領域をそのまま引き継ぐ")
    func findingKeepsRegion() {
        let region = Region(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let texts = [RecognizedText(text: "090-1234-5678", confidence: 1, region: region)]

        #expect(sut.findings(in: texts).first?.region == region)
    }

    @Test("閾値は Rules から差し替えられる")
    func thresholdIsConfigurable() {
        let strict = FindingPolicy(
            rules: FindingRules(
                minimumConfidence: 0.95,
                municipalityMarkers: FindingRules.standard.municipalityMarkers,
                credentialLabels: FindingRules.standard.credentialLabels,
                cardNumberDigits: FindingRules.standard.cardNumberDigits,
                maskedTrailingDigits: FindingRules.standard.maskedTrailingDigits,
                bystanderFaceMaxArea: FindingRules.standard.bystanderFaceMaxArea,
                bystanderFaceEdgeMargin: FindingRules.standard.bystanderFaceEdgeMargin,
                bystanderFaceMinYaw: FindingRules.standard.bystanderFaceMinYaw
            )
        )
        let texts = [RecognizedText(text: "090-1234-5678", confidence: 0.9, region: .test)]

        #expect(sut.findings(in: texts).count == 1)
        #expect(strict.findings(in: texts).isEmpty)
    }

    @Test("全種類に少なくとも1つの判定ルールがある")
    func everyKindIsReachable() {
        let samples: [FindingKind: String] = [
            .cardNumber: "4111 1111 1111 1111",
            .identityDocumentNumber: "AB1234567",
            .credential: "パスワード: hunter2",
            .phoneNumber: "090-1234-5678",
            .email: "yamada@example.com",
            .postalCode: "〒150-0041",
            .address: "渋谷区神南1-2-3"
        ]

        // bystanderFace は文字ではなく顔から来るので、この表には無い（顔のテストは別節）
        for expected in FindingKind.allCases where expected != .bystanderFace {
            let sample = try? #require(samples[expected])
            #expect(sample.flatMap { kind(of: $0) } == expected)
        }
    }
}
