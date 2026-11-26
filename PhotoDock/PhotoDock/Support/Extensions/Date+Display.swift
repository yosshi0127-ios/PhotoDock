//
//  Date+Display.swift
//  PhotoDock
//

import Foundation

extension Date {
    /// 「2026年11月25日」。画面の文言が日本語なので、日付も端末の言語によらず日本語の書き方にそろえる
    /// （英語の端末だと「Nov 25, 2026 診断」と混ざる）。
    /// Text の format: に渡すと画面の言語設定で上書きされるので、文字列にしてから渡す
    /// 「11月25日」。今年でなければ年も付ける（「2025年11月25日」）。見出しなど、短く見せたい場所で使う
    var reportShortDayText: String {
        let isThisYear = Calendar.current.isDate(self, equalTo: .now, toGranularity: .year)
        let style = isThisYear ? Date.FormatStyle.dateTime.month().day() : Date.FormatStyle.dateTime.year().month().day()
        return formatted(style.locale(Locale(identifier: "ja_JP")))
    }

    var reportDayText: String {
        formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP")))
    }
}
