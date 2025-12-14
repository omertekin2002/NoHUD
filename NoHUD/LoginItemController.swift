//
//  LoginItemController.swift
//  NoHUD
//

import Foundation
import ServiceManagement

@MainActor
final class LoginItemController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not registered"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notFound:
            return "Not found (build/signing issue)"
        @unknown default:
            return "Unknown"
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // UI will surface issues through statusDescription, but keep a breadcrumb in logs.
            NSLog("NoHUD: failed to update login item state: \(error.localizedDescription)")
        }
    }
}


