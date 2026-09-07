//
//  PhotoDockApp.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/01.
//

import SwiftUI

@main
struct PhotoDockApp: App {
    init() {
        LiveDependencies.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
