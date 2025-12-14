//
//  PermissionsManager.swift
//  NoHUD
//

import AppKit
import ApplicationServices
import Foundation

final class PermissionsManager {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: true] as [String: Bool] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        // Privacy & Security → Accessibility
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        // Privacy & Security → Input Monitoring
        // Note: Apple has changed pane IDs over time; this is best-effort.
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}


