//
//  NoHUDApp.swift
//  NoHUD
//
//  A tiny menu-bar app that suppresses the system volume/brightness HUD by
//  intercepting media keys and applying the changes itself (no replacement HUD).
//

import SwiftUI

@main
struct NoHUDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NoHUD", systemImage: "speaker.slash.fill") {
            NoHUDMenuView()
                .environmentObject(appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}


