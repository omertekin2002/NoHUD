//
//  NoHUDModel.swift
//  NoHUD
//

import AppKit
import Combine
import Foundation

@MainActor
final class NoHUDModel: ObservableObject {
    @Published private(set) var isAccessibilityTrusted: Bool = false
    @Published private(set) var isSuppressing: Bool = false
    @Published private(set) var volumeInterceptionWorking: Bool = true
    @Published private(set) var brightnessInterceptionWorking: Bool = true
    @Published private(set) var lastError: String?

    @Published private(set) var startAtLoginEnabled: Bool = false
    @Published private(set) var startAtLoginStatus: String = "Unknown"

    @Published var suppressionEnabled: Bool = true

    private let permissions = PermissionsManager()
    private let suppressor = MediaKeySuppressor()
    private let loginItem = LoginItemController()

    private var statusTimer: Timer?

    func startup() {
        // Prompt on first run if needed (macOS shows a system prompt).
        if !permissions.isTrusted {
            permissions.requestAccessibilityPermission()
        }

        refreshAll()

        // Poll for permission changes and suppressor status; keeps the menu accurate.
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }
    }

    func shutdown() {
        statusTimer?.invalidate()
        statusTimer = nil
        suppressor.stop()
    }

    // MARK: - UI Actions

    func toggleSuppression(_ enabled: Bool) {
        suppressionEnabled = enabled
        refreshSuppression()
    }

    func requestAccessibility() {
        permissions.requestAccessibilityPermission()
        refreshAll()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissions.openInputMonitoringSettings()
    }

    func setStartAtLoginEnabled(_ enabled: Bool) {
        loginItem.setEnabled(enabled)
        refreshAll()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - State Refresh

    private func refreshAll() {
        isAccessibilityTrusted = permissions.isTrusted

        // Login item state
        startAtLoginEnabled = loginItem.isEnabled
        startAtLoginStatus = loginItem.statusDescription

        refreshSuppression()
    }

    private func refreshSuppression() {
        guard suppressionEnabled else {
            suppressor.stop()
            syncFromSuppressor()
            return
        }

        guard permissions.isTrusted else {
            suppressor.stop()
            syncFromSuppressor()
            return
        }

        _ = suppressor.start()
        syncFromSuppressor()
    }

    private func syncFromSuppressor() {
        isSuppressing = suppressor.isRunning
        volumeInterceptionWorking = suppressor.volumeInterceptionWorking
        brightnessInterceptionWorking = suppressor.brightnessInterceptionWorking
        lastError = suppressor.lastError
    }
}


