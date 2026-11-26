//
//  Date+Display.swift
//  PhotoDock
//

import Foundation

extension Date {
    /// 「2026年11月25日」。画面の文言が日本語なので、日付も端末の言語によらず日本語の書き方にそろえる
    /// （英語の端末だと「Nov 25, 2026 診断」と混ざる）。
    /// Text の format: に渡すと画面の言語設定で上書きされるので、文字列にしてから渡す
    var reportDayText: String {
        formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP")))
    }
}
