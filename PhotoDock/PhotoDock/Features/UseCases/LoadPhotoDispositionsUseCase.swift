//
//  LoadPhotoDispositionsUseCase.swift
//  PhotoDock
//

import Dependencies

/// 写真への対応（問題なし・非表示・削除）をすべて読む。
/// 読めなければ空 = 「まだ何も対応していない」として扱う
/// （対応済みの写真が未対応に見えるが、読めないせいで所見を隠すよりよい）
struct LoadPhotoDispositionsUseCase: Sendable {
    @Dependency(\.photoDispositions) private var photoDispositions

    func callAsFunction() async -> [PhotoDisposition] {
        (try? await photoDispositions.allDispositions()) ?? []
    }
}
