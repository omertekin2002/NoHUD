//
//  AppDelegate.swift
//  NoHUD
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = NoHUDModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the app headless and out of the Dock (also set via LSUIElement in Info.plist keys).
        NSApplication.shared.setActivationPolicy(.accessory)

        model.startup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }
}


