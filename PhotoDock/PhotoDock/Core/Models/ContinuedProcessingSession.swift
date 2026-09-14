//
//  ContinuedProcessingSession.swift
//  PhotoDock
//

import Foundation

/// OS の表示に使う、処理の説明
struct ContinuedWork: Sendable, Equatable {
    /// 例:「写真を診断しています」
    let title: String
    /// 例:「0 / 3,357 枚」
    let subtitle: String
    /// 進捗の分母
    let totalUnits: Int
}

/// 申告中の処理1件のハンドル。進捗は OS が「止まっていないか」の判断に使うので、区切りごとに必ず報告する。
///
/// protocol ではなくクロージャを持つ値型にしている。Core/Services の protocol は
/// 「DI に登録する依存」として arch-check が登録漏れを検査するので、依存が返すただのハンドルを
/// protocol にすると誤検出になる。中身（OS への伝え方）は Infrastructure が init で差し込む
struct ContinuedProcessingSession: Sendable {
    private let onReport: @Sendable (Int, String) async -> Void
    private let onEnd: @Sendable (Bool) async -> Void

    init(
        report: @escaping @Sendable (_ completedUnits: Int, _ subtitle: String) async -> Void,
        end: @escaping @Sendable (_ success: Bool) async -> Void
    ) {
        self.onReport = report
        self.onEnd = end
    }

    /// 進捗を OS に伝える。completedUnits は ContinuedWork.totalUnits に対する完了数
    func report(completedUnits: Int, subtitle: String) async {
        await onReport(completedUnits, subtitle)
    }

    /// 処理の終わりを OS に伝える。呼ばないと OS がアプリを強制終了しうる
    func end(success: Bool) async {
        await onEnd(success)
    }
}
