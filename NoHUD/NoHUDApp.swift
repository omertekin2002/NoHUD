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
    @ObservedObject private var settings = NoHUDSettings.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var menuBarIconEnabled: Bool =
        UserDefaults.standard.object(forKey: NoHUDSettings.menuBarIconEnabledDefaultsKey) != nil
            ? UserDefaults.standard.bool(forKey: NoHUDSettings.menuBarIconEnabledDefaultsKey)
            : true

    var body: some Scene {
        MenuBarExtra(isInserted: $menuBarIconEnabled) {
            NoHUDMenuView()
                .environmentObject(appDelegate.model)
        } label: {
            NoHUDMenuBarLabelView(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
        // Keep `MenuBarExtra(isInserted:)` driven by @State (prevents SwiftUI/KVO feedback loops),
        // while still syncing the user's preference to persisted settings.
        .onChange(of: menuBarIconEnabled) { newValue in
            if settings.menuBarIconEnabled != newValue {
                settings.menuBarIconEnabled = newValue
            }
        }
        .onChange(of: settings.menuBarIconEnabled) { newValue in
            if menuBarIconEnabled != newValue {
                menuBarIconEnabled = newValue
            }
        }
    }
}

private struct NoHUDMenuBarLabelView: View {
    @ObservedObject var model: NoHUDModel

    var body: some View {
        Label(
            "NoHUD",
            systemImage: model.suppressionEnabled ? "rectangle.dashed" : "rectangle.fill"
        )
    }
}


