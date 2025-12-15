//
//  NoHUDMainWindowView.swift
//  NoHUD
//

import SwiftUI

struct NoHUDMainWindowView: View {
    @EnvironmentObject private var model: NoHUDModel
    @EnvironmentObject private var settings: NoHUDSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NoHUD")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            Toggle("Show menu bar icon", isOn: $settings.menuBarIconEnabled)

            Toggle(
                "Start at login",
                isOn: Binding(
                    get: { model.startAtLoginEnabled },
                    set: { model.setStartAtLoginEnabled($0) }
                )
            )
            .help(model.startAtLoginStatus)

            Divider()

            HStack(spacing: 12) {
                Button("Request Accessibility Permission") {
                    model.requestAccessibility()
                }

                Button("Open Accessibility Settings") {
                    model.openAccessibilitySettings()
                }
            }

            Divider()

            Button("Quit NoHUD") {
                model.quit()
            }
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 0)

            Text("Copyright © Ömer Tekin")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 420)
    }
}


