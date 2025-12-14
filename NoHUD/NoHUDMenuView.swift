//
//  NoHUDMenuView.swift
//  NoHUD
//

import SwiftUI

struct NoHUDMenuView: View {
    @EnvironmentObject private var model: NoHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NoHUD")
                .font(.headline)

            Divider()

            Toggle(
                "Enable suppression",
                isOn: Binding(
                    get: { model.suppressionEnabled },
                    set: { model.toggleSuppression($0) }
                )
            )

            HStack {
                Text("Suppressing")
                Spacer()
                Text(model.isSuppressing ? "On" : "Off")
            }

            HStack {
                Text("Accessibility")
                Spacer()
                Text(model.isAccessibilityTrusted ? "Granted" : "Not granted")
            }

            if model.isAccessibilityTrusted {
                HStack {
                    Text("Volume interception")
                    Spacer()
                    Text(model.volumeInterceptionWorking ? "Working" : "Fallback")
                }

                HStack {
                    Text("Brightness interception")
                    Spacer()
                    Text(model.brightnessInterceptionWorking ? "Working" : "Fallback")
                }
            }

            if let lastError = model.lastError, !lastError.isEmpty {
                Divider()
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260, alignment: .leading)
            }

            Divider()

            Button("Request Accessibility Permission") {
                model.requestAccessibility()
            }

            Button("Open Accessibility Settings") {
                model.openAccessibilitySettings()
            }

            Button("Open Input Monitoring Settings") {
                model.openInputMonitoringSettings()
            }

            Divider()

            Toggle(
                "Start at login",
                isOn: Binding(
                    get: { model.startAtLoginEnabled },
                    set: { model.setStartAtLoginEnabled($0) }
                )
            )
            .help(model.startAtLoginStatus)

            Divider()

            Button("Quit NoHUD") {
                model.quit()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
}


