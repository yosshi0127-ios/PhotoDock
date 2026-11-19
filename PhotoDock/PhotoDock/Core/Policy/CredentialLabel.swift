//
//  CredentialLabel.swift
//  PhotoDock
//

/// 認証情報のラベル語。**照合用と表示用を分ける**。
/// 照合は正規化した形（`apiキー`）で行い、マスクには元の表記（`APIキー`）を出す。
/// pattern は display から導出するので、追加するときは表示したい文字列だけを書けばよい。
struct CredentialLabel: Sendable, Equatable {
    /// マスク後の表示に出る文字列
    let display: String
    /// 照合に使う正規化済みの文字列
    let pattern: String

    init(_ display: String) {
        self.display = display
        self.pattern = display.normalizedForLabelMatch()
    }

    /// 行の中でこのラベルが現れるたびに、その**直後に続く元の文字列**を返す。
    /// 照合は正規化した形で行うが、「ラベルの後ろに値があるか」は区切り記号や空白を
    /// 見ないと判断できないので、正規化前の文字列に戻して返す。
    func remainders(in text: String) -> [Substring] {
        let normalized = text.labelMatchScalars()
        let needle = Array(pattern.unicodeScalars)
        guard !needle.isEmpty, normalized.count >= needle.count else { return [] }

        var remainders: [Substring] = []

        for start in 0...(normalized.count - needle.count) {
            let window = normalized[start..<(start + needle.count)]
            guard window.elementsEqual(needle, by: { $0.scalar == $1 }) else { continue }

            // 一致した最後の文字の「元の文字列での次の位置」から後ろ
            let end = normalized[start + needle.count - 1].sourceEnd
            remainders.append(Substring(text.unicodeScalars[end...]))
        }

        return remainders
    }
}

extension String {
    /// ラベル照合用の正規化。同じ関数を入力側にも通すのでズレようがない。
    ///
    /// - 小文字化: `Password` → `password`
    /// - 全角英数を半角へ: `Ａｐｉ` → `api`（**カタカナは対象外**。
    ///   Foundation の `.fullwidthToHalfwidth` はカタカナも半角にするので使えない
    ///   — 「パスワード」が「ﾊﾟｽﾜｰﾄﾞ」になり既存のラベルが全滅する）
    /// - 空白と区切り記号を除去: `API_KEY` / `api-key` / `API キー` を同じ形に寄せる
    func normalizedForLabelMatch() -> String {
        var result = ""
        result.unicodeScalars.append(contentsOf: labelMatchScalars().map(\.scalar))
        return result
    }

    /// 正規化した文字と、それぞれが元の文字列のどこから来たか（元の文字の直後の位置）の対。
    /// `normalizedForLabelMatch()` はこれを文字列に戻しただけなので、照合と位置の対応がズレない。
    fileprivate func labelMatchScalars() -> [(scalar: Unicode.Scalar, sourceEnd: String.UnicodeScalarView.Index)] {
        var result: [(scalar: Unicode.Scalar, sourceEnd: String.UnicodeScalarView.Index)] = []

        for index in unicodeScalars.indices {
            let sourceEnd = unicodeScalars.index(after: index)

            for scalar in unicodeScalars[index].properties.lowercaseMapping.unicodeScalars {
                // 全角英数・全角記号（U+FF01...U+FF5E）は半角に寄せる
                let halfwidth = (0xFF01...0xFF5E).contains(scalar.value)
                    ? Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
                    : scalar

                guard !halfwidth.properties.isWhitespace,
                      !Self.labelSeparators.contains(halfwidth) else { continue }

                result.append((halfwidth, sourceEnd))
            }
        }

        return result
    }

    /// 全角は半角に寄せた後で判定されるので、ここは半角と全角中黒だけでよい
    private static let labelSeparators: Set<Unicode.Scalar> = ["-", "_", ":", "=", ".", "/", "・"]
}
