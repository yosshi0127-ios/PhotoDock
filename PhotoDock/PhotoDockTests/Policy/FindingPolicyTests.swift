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
        "暗証番号 1234"
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

    /// 桁数を漏らさないため、実際の長さと無関係な固定長にする
    @Test("認証情報はラベル語だけ残して固定長で伏せる")
    func maskedCredential() {
        #expect(sut.masked("パスワード: hunter2", as: .credential) == "パスワード ********")
        #expect(sut.masked("パスワード: aVeryLongPassphrase", as: .credential) == "パスワード ********")
    }

    @Test("メールはローカル部の先頭1文字とドメインを残し、周りの文字はそのまま")
    func maskedEmail() {
        #expect(
            sut.masked("連絡先は yamada@example.com です", as: .email)
                == "連絡先は y*****@example.com です"
        )
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
                maskedTrailingDigits: FindingRules.standard.maskedTrailingDigits
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

        for expected in FindingKind.allCases {
            let sample = try? #require(samples[expected])
            #expect(sample.flatMap { kind(of: $0) } == expected)
        }
    }
}
