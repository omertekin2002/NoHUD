//
//  NoHUDMainWindowController.swift
//  NoHUD
//

import AppKit
import SwiftUI

@MainActor
final class NoHUDMainWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onHideRequested: () -> Void

    init(model: NoHUDModel, settings: NoHUDSettings, onHideRequested: @escaping () -> Void) {
        self.onHideRequested = onHideRequested

        let rootView = NoHUDMainWindowView()
            .environmentObject(model)
            .environmentObject(settings)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "NoHUD"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()

        self.window = window

        super.init()

        window.delegate = self
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Keep the app running; just hide the GUI window.
        onHideRequested()
        return false
    }
}


