//
//  String+MatchNormalization.swift
//  PhotoDock
//

extension String {
    /// 判定の入口で1回だけ通す正規化。全種類の判定がこの結果を見る。
    ///
    /// 日本語の文書では数字・英字・記号が全角で書かれ、ハイフンには見た目の同じ別の文字が
    /// いくつも使われる。判定側は半角の `[0-9]` と `-` だけを相手にすればよいようにする。
    ///
    /// - 全角の英数記号（U+FF01...U+FF5E）を半角へ: `０９０` → `090`、`＠` → `@`
    /// - 全角空白を半角空白へ
    /// - ハイフンの異体（`‐` `‑` `‒` `–` `—` `―` `−`）を `-` へ
    /// - 長音記号（`ー` `ｰ`）は**数字に挟まれているときだけ** `-` へ（`090ー1234ー5678`）。
    ///   無条件に変えると「パスワード」や「サーバー」が壊れる
    ///
    /// **カタカナには触らない**（Foundation の `.fullwidthToHalfwidth` はカタカナも半角にする）。
    /// 文字は1対1で置き換えるので、文字数と位置は元の文字列と変わらない
    /// （正規化した文字列をそのままマスクしても、伏せる位置がズレない）。
    func normalizedForMatching() -> String {
        var scalars = unicodeScalars.map(Self.foldedForMatching)

        for index in scalars.indices where Self.prolongedSoundMarks.contains(scalars[index]) {
            guard index > 0, index + 1 < scalars.count,
                  Self.isASCIIDigit(scalars[index - 1]),
                  Self.isASCIIDigit(scalars[index + 1]) else { continue }

            scalars[index] = "-"
        }

        var result = ""
        result.unicodeScalars.append(contentsOf: scalars)
        return result
    }

    private static func foldedForMatching(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar.value {
        case 0xFF01...0xFF5E:
            Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
        case 0x3000:
            " "
        default:
            hyphenVariants.contains(scalar) ? "-" : scalar
        }
    }

    /// `‐`(2010) `‑`(2011) `‒`(2012) `–`(2013) `—`(2014) `―`(2015) `−`(2212)。
    /// 全角ハイフンマイナス（FF0D）は全角記号の範囲に入っているので、ここには要らない
    private static let hyphenVariants: Set<Unicode.Scalar> = [
        "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}", "\u{2212}"
    ]

    /// `ー`(30FC) と半角の `ｰ`(FF70)
    private static let prolongedSoundMarks: Set<Unicode.Scalar> = ["\u{30FC}", "\u{FF70}"]

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        (0x30...0x39).contains(scalar.value)
    }
}
