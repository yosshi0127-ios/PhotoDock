//
//  PhotoDockApp.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/01.
//

import Foundation
import SwiftUI

@main
struct PhotoDockApp: App {
    /// ユニットテストは**このアプリをホストにして**動く（テストバンドルがアプリのプロセスへ注入される）。
    /// そのままだと ScanHomeView の `.task` が走り、テスト文脈で解決される
    /// `testValue`(Unimplemented) を踏んでテストホストごと落ちる。
    /// そのためテスト実行時は画面を組み立てない。
    ///
    /// UI テストは別プロセスの runner からアプリを起動するため、この判定には該当しない（通常どおり起動する）。
    private static let isRunningUnitTests = NSClassFromString("XCTestCase") != nil

    var body: some Scene {
        WindowGroup {
            if Self.isRunningUnitTests {
                EmptyView()
            } else {
                RootView()
            }
        }
    }
}
