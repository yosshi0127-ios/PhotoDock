//
//  RootView.swift
//  PhotoDock
//

import SwiftUI

/// アプリの入口。今は診断ホーム1枚だが、タブや起動時の分岐が増えたらここで組む。
struct RootView: View {
    var body: some View {
        NavigationStack {
            ScanHomeView()
        }
    }
}

#Preview {
    RootView()
}
