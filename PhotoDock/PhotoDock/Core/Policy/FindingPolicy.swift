//
//  FindingPolicy.swift
//  PhotoDock
//

/// 認識テキスト → 所見の分類。純粋関数のみ（依存なし・同期・副作用なし）。
///
/// 判定は正規表現・チェックサム・語彙で行う。生成モデルを使わない理由は
/// deployment target（iOS 18 対象 / Foundation Models は 26 以降）・速度（3万枚）・
/// 決定性（インデックスの再スキャン判定が同一結果を前提にしている）・
/// 全網羅テストの可否の4点。知覚は ML（Vision）、判断はルールという切り分け。
struct FindingPolicy: Sendable {
    let rules: FindingRules

    init(rules: FindingRules = .standard) {
        self.rules = rules
    }

    /// 1枚ぶんの認識結果を所見に変換する。
    /// 確度の低い行は誤読として捨て、1行につき最大1件の所見を作る。
    func findings(in texts: [RecognizedText]) -> [Finding] {
        let classified = texts
            .filter { $0.confidence >= rules.minimumConfidence }
            .compactMap { recognized -> Finding? in
                guard let match = classify(recognized.text) else { return nil }

                return Finding(
                    kind: match.kind,
                    severity: match.severity,
                    region: recognized.region,
                    maskedText: masked(recognized.text, as: match.kind)
                )
            }

        return escalated(classified)
    }

    /// 複合判定（氏名 + 生年月日 + 住所が揃えば本人確認書類、など）の置き場。
    /// 構成要素の kind が第2弾以降なので、今は何も引き上げない。
    /// 先に経路を通しておくことで、追加時に Finding の生成側を触らずに済む。
    func escalated(_ findings: [Finding]) -> [Finding] {
        findings
    }

    // MARK: - 判定

    /// 「確実な順・情報量の多い順」に試し、最初に一致した1件を返す。
    ///
    /// 順序に意味がある:
    /// - `パスワード: 090-1234-5678` は認証情報として拾う（ラベル語があれば意図が明確）
    /// - `03-1234-5678` は電話番号。部分文字列が郵便番号の書式にも当たるが、電話が先に勝つ
    /// - `〒150-0041 渋谷区神南1-2-3` は住所。郵便番号より情報量が多いほうを取る
    func classify(_ text: String) -> (kind: FindingKind, severity: Severity)? {
        if hasCardNumber(text) { return (.cardNumber, .danger) }
        if hasCredentialLabel(text) { return (.credential, .danger) }
        if text.contains(/\b[A-Z]{2}[0-9]{7}\b/) { return (.identityDocumentNumber, .caution) }
        if text.contains(emailPattern) { return (.email, .caution) }
        if hasAddress(text) { return (.address, .caution) }
        if hasPhoneNumber(text) { return (.phoneNumber, .caution) }
        if text.contains(/[0-9]{3}-[0-9]{4}/) { return (.postalCode, .caution) }

        return nil
    }

    private func hasCardNumber(_ text: String) -> Bool {
        digitRuns(in: text).contains {
            rules.cardNumberDigits.contains($0.count) && isLuhnValid($0)
        }
    }

    /// 空白とハイフンを除いてから、連続する数字の並びを取り出す
    /// （Vision は `4111 1111 1111 1111` と区切り込みで返す — 実測済み）
    private func digitRuns(in text: String) -> [String] {
        text
            .filter { !$0.isWhitespace && $0 != "-" }
            .split { !$0.isNumber }
            .map(String.init)
    }

    private func isLuhnValid(_ digits: String) -> Bool {
        var sum = 0

        for (offset, character) in digits.reversed().enumerated() {
            guard let value = character.wholeNumberValue else { return false }

            if offset.isMultiple(of: 2) {
                sum += value
            } else {
                let doubled = value * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }

        return sum.isMultiple(of: 10)
    }

    private func hasCredentialLabel(_ text: String) -> Bool {
        matchedCredentialLabel(in: text) != nil
    }

    private func matchedCredentialLabel(in text: String) -> String? {
        let lowered = text.lowercased()
        return rules.credentialLabels.first { lowered.contains($0) }
    }

    /// 市区町村の文字 + 番地パターン。都道府県は要求しない（省略されるのが普通）。
    /// `番` 単体を許さないのは `○○市 3番線` のような駅の表示を拾わないため。
    /// 2連の `\d+-\d+` を番地とみなさないのは `8:30-17:15` のような時刻範囲に当たるため。
    private func hasAddress(_ text: String) -> Bool {
        let hasMunicipality = text.contains { rules.municipalityMarkers.contains($0) }
        let hasBlockNumber = text.contains(/[0-9]+-[0-9]+-[0-9]+/)
            || text.contains(/[0-9]+丁目/)
            || text.contains(/[0-9]+番地/)

        return hasMunicipality && hasBlockNumber
    }

    private func hasPhoneNumber(_ text: String) -> Bool {
        text.contains(/0[789]0-?[0-9]{4}-?[0-9]{4}/)
            || text.contains(/0[0-9]{1,3}-[0-9]{2,4}-[0-9]{4}/)
    }

    // MARK: - マスク

    /// 表示用のマスク。何が写っているかは伝えるが、本文は復元できない形にする。
    func masked(_ text: String, as kind: FindingKind) -> String {
        switch kind {
        case .credential:
            maskedCredential(text)
        case .email:
            maskedEmail(text)
        case .address:
            // 番地を残さない。漢字はそのまま残るので「どこの住所か」の識別はできる
            maskedDigits(text, keepingTrailing: 0)
        case .cardNumber, .identityDocumentNumber, .phoneNumber, .postalCode:
            maskedDigits(text, keepingTrailing: rules.maskedTrailingDigits)
        }
    }

    /// 数字だけを伏せ、末尾の指定桁数だけ残す。区切り記号と文字はそのまま
    /// （`4111 1111 1111 1111` → `**** **** **** 1111`）。
    private func maskedDigits(_ text: String, keepingTrailing keepCount: Int) -> String {
        let digitCount = text.count { $0.isNumber }
        var seen = 0

        return String(text.map { character in
            guard character.isNumber else { return character }

            seen += 1
            return seen > digitCount - keepCount ? character : "*"
        })
    }

    /// ラベル語だけ残し、値は固定長で伏せる。
    /// 桁数を漏らさないために、実際の長さと無関係な固定長にしている。
    private func maskedCredential(_ text: String) -> String {
        guard let label = matchedCredentialLabel(in: text) else {
            return String(repeating: "*", count: 8)
        }

        return "\(label) ********"
    }

    /// ローカル部の先頭1文字とドメインを残す（`yamada@example.com` → `y*****@example.com`）。
    /// ドメインは機微度が低く、どのアカウントかの識別に役立つ。星の数は固定（長さを漏らさない）。
    private func maskedEmail(_ text: String) -> String {
        guard let match = text.firstMatch(of: emailPattern) else { return text }

        let address = match.output
        guard let atIndex = address.firstIndex(of: "@"), let first = address.first else { return text }

        let maskedAddress = "\(first)*****\(address[atIndex...])"
        let prefix = text[..<match.range.lowerBound]
        let suffix = text[match.range.upperBound...]

        return "\(prefix)\(maskedAddress)\(suffix)"
    }

    // MARK: - パターン

    /// 判定とマスクの2箇所で使うので、パターンの二重管理を避けるためここに置く。
    /// `Regex` は Sendable でないので `static let` にできない（Swift 6 の並列チェック）。
    /// `nonisolated(unsafe)` で回避せず computed property にしている
    /// — 1箇所しか使わない他のパターンは呼び出し側にインラインで書く。
    private var emailPattern: Regex<Substring> {
        /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
    }
}

