//
//  AppDelegate.swift
//  NoHUD
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = NoHUDModel()
    let settings = NoHUDSettings.shared

    private var mainWindowController: NoHUDMainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire model actions that must be mediated by the app delegate.
        model.onQuitRequested = { [weak self] in
            self?.requestQuit()
        }
        model.onShowMainWindowRequested = { [weak self] in
            self?.showMainWindow()
        }

        // Create and show the GUI window on launch (and show Dock icon while it is visible).
        mainWindowController = NoHUDMainWindowController(
            model: model,
            settings: settings,
            onHideRequested: { [weak self] in
                self?.hideMainWindow()
            }
        )

        showMainWindow()

        model.startup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If the user launches the app again (Spotlight/Finder), bring back the GUI.
        showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }

    // MARK: - Window + Lifecycle helpers

    private func requestQuit() {
        NSApp.terminate(nil)
    }

    private func showMainWindow() {
        setDockIconVisible(true)
        mainWindowController?.show()
    }

    private func hideMainWindow() {
        mainWindowController?.hide()
        setDockIconVisible(false)
    }

    private func setDockIconVisible(_ visible: Bool) {
        NSApplication.shared.setActivationPolicy(visible ? .regular : .accessory)
        if visible {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}


