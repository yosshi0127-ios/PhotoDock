//
//  ReportItemLayout.swift
//  PhotoDock
//

extension ReportItemView {
    /// 項目の一覧の並べ方
    enum Layout: Equatable {
        /// 1枚を1行で。撮った日と、ほかに写っている種類が分かる
        case rows
        /// 3列の格子で。写真だけ
        case grid

        var other: Layout {
            switch self {
            case .rows: .grid
            case .grid: .rows
            }
        }

        /// 切り替えボタンの名前（押すとどうなるか）
        var switchLabel: String {
            switch self {
            case .rows: "格子で表示"
            case .grid: "1行ずつ表示"
            }
        }

        var switchSymbol: String {
            switch self {
            case .rows: "square.grid.3x3"
            case .grid: "list.bullet"
            }
        }
    }
}
