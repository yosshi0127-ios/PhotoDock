//
//  RequestPhotoAccessUseCase.swift
//  PhotoDock
//

import Dependencies

/// 写真へのアクセスを求める。**確認ダイアログが出るのはここだけ**。
///
/// ホームを開いただけでは呼ばない。初回の案内で約束を見せ、ユーザーがボタンを押してから呼ぶ
/// （`LoadScanHomeUseCase` は今の状態を読むだけで、ダイアログを出さない）
struct RequestPhotoAccessUseCase: Sendable {
    @Dependency(\.photoLibrary) private var photoLibrary

    @discardableResult
    func callAsFunction() async -> PhotoLibraryAccess {
        await photoLibrary.requestAccess()
    }
}
