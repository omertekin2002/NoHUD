//
//  NoHUDSettings.swift
//  NoHUD
//

import Combine
import Foundation

@MainActor
final class NoHUDSettings: ObservableObject {
    static let shared = NoHUDSettings()
    static let menuBarIconEnabledDefaultsKey = "NoHUD.menuBarIconEnabled"

    @Published var menuBarIconEnabled: Bool = true {
        didSet {
            guard oldValue != menuBarIconEnabled else { return }
            UserDefaults.standard.set(menuBarIconEnabled, forKey: Self.menuBarIconEnabledDefaultsKey)
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.menuBarIconEnabledDefaultsKey) != nil {
            menuBarIconEnabled = UserDefaults.standard.bool(forKey: Self.menuBarIconEnabledDefaultsKey)
        } else {
            menuBarIconEnabled = true
        }
    }
}


