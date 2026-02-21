//
//  SettingsManager.swift
//  OffVeil
//
//  Created by AI Assistant on 4.02.2026.
//

import Foundation
import ServiceManagement

enum AppLanguage: String, CaseIterable {
    case en
    case tr

    var title: String {
        switch self {
        case .en:
            return "English"
        case .tr:
            return "Turkce"
        }
    }
}

enum AppTheme: String, CaseIterable {
    case energy
    case classic
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let autoActivateOnLaunch = "autoActivateOnLaunch"
        static let startHiddenOnLaunch = "startHiddenOnLaunch"
        static let appLanguage = "appLanguage"
        static let appTheme = "appTheme"
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItem()

            if !launchAtLogin {
                autoActivateOnLaunch = false
                startHiddenOnLaunch = false
            }
        }
    }
    
    @Published var autoActivateOnLaunch: Bool {
        didSet {
            defaults.set(autoActivateOnLaunch, forKey: Keys.autoActivateOnLaunch)
        }
    }

    @Published var startHiddenOnLaunch: Bool {
        didSet {
            defaults.set(startHiddenOnLaunch, forKey: Keys.startHiddenOnLaunch)
        }
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
        }
    }

    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        }
    }
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.autoActivateOnLaunch = defaults.bool(forKey: Keys.autoActivateOnLaunch)
        self.startHiddenOnLaunch = defaults.bool(forKey: Keys.startHiddenOnLaunch)

        if let savedLanguage = defaults.string(forKey: Keys.appLanguage),
           let parsedLanguage = AppLanguage(rawValue: savedLanguage) {
            self.appLanguage = parsedLanguage
        } else {
            self.appLanguage = .en
        }

        if let savedTheme = defaults.string(forKey: Keys.appTheme),
           let parsedTheme = AppTheme(rawValue: savedTheme) {
            self.appTheme = parsedTheme
        } else {
            self.appTheme = .classic
        }

        if !launchAtLogin {
            autoActivateOnLaunch = false
            startHiddenOnLaunch = false
        }
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}
