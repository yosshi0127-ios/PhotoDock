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

        for scalar in lowercased().unicodeScalars {
            // 全角英数・全角記号（U+FF01...U+FF5E）は半角に寄せる
            let halfwidth = (0xFF01...0xFF5E).contains(scalar.value)
                ? Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
                : scalar

            guard !halfwidth.properties.isWhitespace,
                  !Self.labelSeparators.contains(halfwidth) else { continue }

            result.unicodeScalars.append(halfwidth)
        }

        return result
    }

    /// 全角は半角に寄せた後で判定されるので、ここは半角と全角中黒だけでよい
    private static let labelSeparators: Set<Unicode.Scalar> = ["-", "_", ":", "=", ".", "/", "・"]
}
