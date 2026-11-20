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

    /// 1枚ぶんの認識結果と検出した顔を所見に変換する。
    /// 確度が閾値未満の行は使わず、1行につき最大1件の所見を作る。
    /// 顔は「写り込みらしい」ものだけを所見にする（撮りたかった人の顔は所見にしない）。
    func findings(in texts: [RecognizedText], faces: [DetectedFace] = []) -> [Finding] {
        let fromTexts = texts
            .filter { $0.confidence >= rules.minimumConfidence }
            .compactMap { recognized -> Finding? in
                // 判定とマスクは同じ正規化済みの行を見る（全角のメールアドレスを
                // 判定では拾えたのにマスクでは見つけられない、という食い違いを作らない）
                let line = recognized.text.normalizedForMatching()
                guard let match = classify(normalized: line) else { return nil }

                return Finding(
                    kind: match.kind,
                    severity: match.severity,
                    region: recognized.region,
                    maskedText: masked(line, as: match.kind)
                )
            }

        let fromFaces = faces
            .filter(isBystander)
            .map { face in
                Finding(
                    kind: .bystanderFace,
                    severity: .caution,   // 幾何の推定なので断定しない
                    region: face.region,
                    maskedText: "他の人かもしれません"
                )
            }

        return escalated(fromTexts + fromFaces)
    }

    /// 小さく、かつ「端にある」か「横を向いている」顔を写り込みらしいとみなす。
    /// 大きく中央で正面の顔は撮りたかった人。誰の顔かは分からないので幾何だけで判断する。
    /// 誤りは両方向に出る（端の友人を拾う / 正面に割り込んだ他人を落とす）ので要注意どまり。
    func isBystander(_ face: DetectedFace) -> Bool {
        let region = face.region
        let margin = rules.bystanderFaceEdgeMargin

        let isSmall = region.width * region.height < rules.bystanderFaceMaxArea
        let isAtEdge = region.x < margin
            || region.y < margin
            || region.x + region.width > 1 - margin
            || region.y + region.height > 1 - margin
        let isTurnedAway = face.yaw.map { abs($0) >= rules.bystanderFaceMinYaw } ?? false

        return isSmall && (isAtEdge || isTurnedAway)
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
    ///
    /// 入口で全角の英数記号とハイフンの異体を半角に寄せる（`normalizedForMatching`）。
    /// 以降の判定は半角の数字と `-` だけを相手にする。
    func classify(_ text: String) -> (kind: FindingKind, severity: Severity)? {
        classify(normalized: text.normalizedForMatching())
    }

    private func classify(normalized text: String) -> (kind: FindingKind, severity: Severity)? {
        if let severity = cardNumberSeverity(in: text) { return (.cardNumber, severity) }
        // 値の書式はラベルより確実なので先に試す
        if hasCredentialValue(text) { return (.credential, .danger) }
        if let severity = credentialLabelSeverity(in: text) { return (.credential, severity) }
        if text.contains(/\b[A-Z]{2}[0-9]{7}\b/) { return (.identityDocumentNumber, .caution) }
        if text.contains(emailPattern) { return (.email, .caution) }
        if hasAddress(text) { return (.address, .caution) }
        if hasPhoneNumber(text) { return (.phoneNumber, .caution) }
        if hasPostalCode(text) { return (.postalCode, .caution) }

        return nil
    }

    /// カード番号が写っている行の危険度。無ければ nil。
    ///
    /// 数字のかたまりを区切りごとに保ったまま、**連続するかたまりの組**を候補にする。
    /// 行全体の数字を1本につなげると、隣の数字を巻き込んで見逃す
    /// （`4111 1111 1111 1111 12/28` が18桁になって Luhn に落ちる）。
    /// - Luhn が通り、番号帯と桁数がブランドに合う → **危険**
    /// - Luhn が通り、ブランドには合わないが4桁×4で書かれている → **要注意**
    private func cardNumberSeverity(in text: String) -> Severity? {
        var severity: Severity?

        for groups in digitClusters(in: text) {
            for start in groups.indices {
                var digits = ""

                for end in start..<groups.count {
                    digits += groups[end]
                    guard digits.count <= rules.cardNumberDigits.upperBound else { break }
                    guard rules.cardNumberDigits.contains(digits.count), isLuhnValid(digits) else { continue }

                    if rules.cardNumberFormats.contains(where: { $0.matches(digits) }) {
                        return .danger
                    }
                    if groups[start...end].map(\.count) == rules.unbrandedCardGrouping {
                        severity = .caution
                    }
                }
            }
        }

        return severity
    }

    /// 数字のかたまりを、近くにあるもの同士でまとめて取り出す（数字は半角に寄せる）。
    /// `4111 1111 1111 1111 12/28` → `[["4111", "1111", "1111", "1111", "12"], ["28"]]`。
    /// かたまり同士をつなぐのは空白とハイフンだけ（合わせて3文字まで。` - ` を許すため）。
    /// それ以外の文字や長い空きを挟んだ数字は別のまとまりにする
    /// （Vision は `4111 1111 1111 1111` と区切り込みで返す — 実測済み）
    private func digitClusters(in text: String) -> [[String]] {
        var clusters: [[String]] = []
        var groups: [String] = []
        var group = ""
        var gap = 0

        func closeCluster() {
            if !group.isEmpty { groups.append(group) }
            if !groups.isEmpty { clusters.append(groups) }
            groups = []
            group = ""
        }

        for character in text {
            if Self.isMaskableDigit(character), let value = character.wholeNumberValue {
                if gap > 0, !group.isEmpty {
                    groups.append(group)
                    group = ""
                }
                group += String(value)
                gap = 0
            } else if character == " " || character == "-", gap < Self.maxClusterGap {
                gap += 1
            } else {
                closeCluster()
                gap = 0
            }
        }
        closeCluster()

        return clusters
    }

    private static let maxClusterGap = 3

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

    /// ラベル語がある行の危険度。ラベルが無ければ nil。
    ///
    /// ラベル語があるだけでは「値が写っている」とは言えない。ログイン画面の
    /// 「パスワードを忘れた方」や設定画面の「パスワードを変更」にもラベル語は出る。
    /// - ラベルの直後に値らしい文字列が続く → **危険**（`パスワード: hunter2`）
    /// - ラベルだけ → **要注意**（値が次の行にある付箋やルーターのラベルを落とさないため、所見には残す）
    ///
    /// 同じ行にラベルが複数回出るときは、どれか1つに値が続けば危険とする。
    private func credentialLabelSeverity(in text: String) -> Severity? {
        let remainders = rules.credentialLabels.flatMap { $0.remainders(in: text) }
        guard !remainders.isEmpty else { return nil }

        return remainders.contains(where: startsWithCredentialValue) ? .danger : .caution
    }

    /// ラベルの直後（空白と区切り記号を飛ばした位置）に、値らしい文字列があるか。
    ///
    /// 値は「空白を含まない半角の英数記号の並び」とみなす（全角は入口の正規化で半角に寄っている）。
    /// - `:` や `=` で区切られていれば、その並びをそのまま値とみなす（`Password: correcthorse`）
    /// - 区切りが無いときは数字を含む並びだけを値とみなす。英語の UI 文言
    ///   （`Password reset` / `Password must be ...`）を値と取り違えないため
    /// - 伏せ字（`********`）のように英数字を1つも含まない並びは値ではない
    ///
    /// 取りこぼしても所見は要注意として残る（危険に上がらないだけで、消えはしない）。
    private func startsWithCredentialValue(_ remainder: Substring) -> Bool {
        var rest = remainder.drop(while: \.isWhitespace)

        let hasSeparator = rest.first.map { Self.credentialValueSeparators.contains($0) } ?? false
        if hasSeparator {
            rest = rest.dropFirst().drop(while: \.isWhitespace)
        }

        let token = rest.prefix { $0.isASCII && !$0.isWhitespace }

        guard token.count >= rules.credentialValueMinLength,
              token.contains(where: { $0.isLetter || $0.isNumber }) else { return false }

        return hasSeparator || token.contains(where: \.isNumber)
    }

    private static let credentialValueSeparators: Set<Character> = [":", "="]

    /// 入力にもラベルと同じ正規化を通してから照合する
    /// （`API_KEY` / `api-key` / `API キー` がどれも `apikey` に寄る）
    private func matchedCredentialLabel(in text: String) -> CredentialLabel? {
        let normalized = text.normalizedForLabelMatch()
        return rules.credentialLabels.first { normalized.contains($0.pattern) }
    }

    /// ラベルが無くても認証情報と断定できる値の書式。
    /// 機械が発行するトークンはプレフィックスが業界固有なので、誤検出はほぼ起きない。
    /// ラベル辞書では表記揺れを網羅できないので、こちらが下支えになる。
    private func hasCredentialValue(_ text: String) -> Bool {
        text.contains(/sk-[A-Za-z0-9_-]{16,}/)                              // OpenAI
            || text.contains(/gh[pousr]_[A-Za-z0-9]{16,}/)                  // GitHub
            || text.contains(/github_pat_[A-Za-z0-9_]{20,}/)                // GitHub（新形式）
            || text.contains(/\bAKIA[0-9A-Z]{16}\b/)                        // AWS
            || text.contains(/xox[baprs]-[A-Za-z0-9-]{10,}/)                // Slack
            || text.contains(/eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\./) // JWT
            || text.contains(/-----BEGIN [A-Z ]*PRIVATE KEY-----/)          // PEM 秘密鍵
    }

    /// 市区町村の文字の**後ろに**番地が続く行を住所とみなす。都道府県は要求しない（省略されるのが普通）。
    ///
    /// 住所は「市区町村 → 町名 → 番地」の順に書くので、番地より前に市区町村の文字が無ければ
    /// 住所ではない。行を先頭から1回なぞり、市区町村の文字を見た後に出てきた数字の並びだけを
    /// 番地の候補にする。
    private func hasAddress(_ text: String) -> Bool {
        let characters = Array(text)
        var index = 0
        var hasSeenMunicipality = false

        while index < characters.count {
            guard Self.isASCIIDigit(characters[index]) else {
                if rules.municipalityMarkers.contains(characters[index]) { hasSeenMunicipality = true }
                index += 1
                continue
            }

            // ハイフンでつながった数字の並びを1つ読む（`1-2-3` → ["1", "2", "3"]）
            let start = index
            var groups = [""]

            while index < characters.count {
                if Self.isASCIIDigit(characters[index]) {
                    groups[groups.count - 1].append(characters[index])
                } else if characters[index] == "-",
                          index + 1 < characters.count,
                          Self.isASCIIDigit(characters[index + 1]) {
                    groups.append("")
                } else {
                    break
                }
                index += 1
            }

            let isBlock = isBlockNumber(
                groups,
                precededBy: start > 0 ? characters[start - 1] : nil,
                followedBy: characters[index...].prefix(2)
            )
            if hasSeenMunicipality, isBlock { return true }
        }

        return false
    }

    /// 数字の並びが番地の書き方か。
    ///
    /// - 漢字の書き方: `1丁目` / `4番地` / `1番2号`。`番` 単体を許さないのは
    ///   `○○市 3番線` のような駅の表示を拾わないため
    /// - `1-2-3`（部屋番号つきの `1-2-3-405` も）: 日付（`2026-09-12`）と電話番号（`03-1234-5678`）、
    ///   桁の多い通し番号（`1234-5678-9012`）を除く
    /// - `4-5`: 町名に直接続くときだけ（`万町4-5`）。空白や記号の後ろの2連は
    ///   時刻の範囲（`8:30-17:15`）や点数（`3-2`）のことが多い
    private func isBlockNumber(
        _ groups: [String],
        precededBy previous: Character?,
        followedBy following: ArraySlice<Character>
    ) -> Bool {
        let next = following.first

        if following.elementsEqual("丁目") || following.elementsEqual("番地") { return true }
        if next == "番", let afterNext = following.dropFirst().first, Self.isASCIIDigit(afterNext) { return true }

        // 番地の数字は 0 で始まらない。0 始まりの並びは日付の月日か電話番号
        guard groups.allSatisfy({ rules.addressBlockGroupDigits.contains($0.count) && !$0.hasPrefix("0") }) else {
            return false
        }

        switch groups.count {
        case 3, 4:
            let block = groups.prefix(3)
            let digitCount = block.reduce(0) { $0 + $1.count }

            return digitCount <= rules.addressBlockMaxDigits && !isDate(Array(block))
        case 2:
            return previous.map(Self.isJapaneseLetter) ?? false && next != ":"
        default:
            return false
        }
    }

    /// 0 埋めの無い日付（`2026-9-12`）。0 埋めのある日付は「0 で始まらない」の条件で先に落ちる
    private func isDate(_ groups: [String]) -> Bool {
        guard groups.count == 3, groups[0].count == 4,
              let year = Int(groups[0]), let month = Int(groups[1]), let day = Int(groups[2]) else {
            return false
        }

        return (1900...2100).contains(year) && (1...12).contains(month) && (1...31).contains(day)
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// 漢字・ひらがな・カタカナ（町名に使われる文字）
    private static func isJapaneseLetter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) || $0 == "々"
        }
    }

    /// 日本の電話番号の書式。もっと長い数字の並びの一部であるときは拾わない
    /// （`注文番号 1209012345678`。前後の条件は郵便番号と同じ）。
    ///
    /// - 携帯と IP 電話（`070` / `080` / `090` / `050`）: 11桁。ハイフンは無くてもよい
    /// - 固定電話とフリーダイヤル: ハイフン区切りで**合計がちょうど10桁**
    ///   （`03-1234-5678` / `0426-12-3456` / `0120-123-456`）。桁数を見ないと
    ///   「月-日-年」の日付（`01-02-2026`）が電話番号になる
    private func hasPhoneNumber(_ text: String) -> Bool {
        if text.contains(/(?:^|[^0-9-])0[5789]0-?[0-9]{4}-?[0-9]{4}(?![0-9]|-[0-9])/) { return true }

        return text.matches(of: /(?:^|[^0-9-])(0[0-9]{1,3}-[0-9]{2,4}-[0-9]{3,4})(?![0-9]|-[0-9])/)
            .contains { $0.output.1.count { $0 != "-" } == rules.landlinePhoneDigits }
    }

    /// `123-4567` の形。ただし、もっと長い数字の並びの一部であるときは郵便番号にしない
    /// （`注文番号 20261119-00123` の `119-0012`、`1234-5678-9012` の `234-5678`）。
    /// 直前が数字かハイフン、直後が数字か「ハイフン + 数字」なら、長い並びの途中とみなす。
    ///
    /// 直前の英字は除外しない。OCR が `〒` を `T` と読むことがあり、
    /// 英字を条件に入れると `T150-0041` を見逃す（代わりに `A123-4567` のような型番は拾う）
    private func hasPostalCode(_ text: String) -> Bool {
        text.contains(/(?:^|[^0-9-])[0-9]{3}-[0-9]{4}(?![0-9]|-[0-9])/)
    }

    // MARK: - マスク

    /// 表示用のマスク。何が写っているかは伝えるが、本文は復元できない形にする。
    func masked(_ text: String, as kind: FindingKind) -> String {
        switch kind {
        case .credential:
            maskedCredential(text)
        case .email:
            maskedEmail(text)
        case .address, .postalCode:
            // 番地を残さない。漢字はそのまま残るので「どこの住所か」の識別はできる。
            // 郵便番号も末尾を残さない（下4桁だけで町域が特定できるため、
            // 「どのカードか」を示すカード番号の末尾4桁とは性質が違う）
            maskedDigits(text, keepingTrailing: 0)
        case .cardNumber, .identityDocumentNumber, .phoneNumber:
            maskedDigits(text, keepingTrailing: rules.maskedTrailingDigits)
        case .bystanderFace:
            text   // 顔は文字を持たない。ここに来ることはないが網羅のために置く
        }
    }

    /// 数字だけを伏せ、末尾の指定桁数だけ残す。区切り記号と文字はそのまま
    /// （`4111 1111 1111 1111` → `**** **** **** 1111`）。
    private func maskedDigits(_ text: String, keepingTrailing keepCount: Int) -> String {
        let digitCount = text.count { Self.isMaskableDigit($0) }
        var seen = 0

        return String(text.map { character in
            guard Self.isMaskableDigit(character) else { return character }

            seen += 1
            return seen > digitCount - keepCount ? character : "*"
        })
    }

    /// 伏せるのは算用数字（半角・全角）だけ。
    /// `Character.isNumber` は漢数字にも true を返すので、それで判定すると
    /// 地名（千代田・京都・三田・六本木…）の漢字まで伏せてしまう。
    private static func isMaskableDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { $0.properties.numericType == .decimal }
    }

    /// ラベル語だけ残し、値は固定長で伏せる。
    /// 桁数を漏らさないために、実際の長さと無関係な固定長にしている。
    /// ラベルが無い行（値の書式だけで拾った行）は伏せ字だけを返す。
    private func maskedCredential(_ text: String) -> String {
        guard let label = matchedCredentialLabel(in: text) else {
            return String(repeating: "*", count: 8)
        }

        return "\(label.display) ********"
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

