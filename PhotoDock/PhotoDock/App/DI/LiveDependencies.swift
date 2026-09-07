//
//  LiveDependencies.swift
//  PhotoDock
//

import Dependencies

/// アプリのプロセスでは常に本番実装を解決させる。
///
/// swift-dependencies は XCTest の環境変数（`XCTestSessionIdentifier` 等）の有無で
/// テスト文脈を判定する。UI テストが起動したアプリにもその環境変数が渡るため、
/// ここで明示しないと testValue（Unimplemented）が解決されて起動直後に落ちる。
/// Preview はアプリの init を通らないので previewValue のままで影響しない。
enum LiveDependencies {
    static func prepare() {
        prepareDependencies { $0.context = .live }
    }
}
