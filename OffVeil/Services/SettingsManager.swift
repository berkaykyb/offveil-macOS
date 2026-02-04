//
//  SettingsManager.swift
//  OffVeil
//
//  Created by AI Assistant on 4.02.2026.
//

import Foundation
import ServiceManagement

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let showNotifications = "showNotifications"
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItem()
        }
    }
    
    @Published var showNotifications: Bool {
        didSet {
            defaults.set(showNotifications, forKey: Keys.showNotifications)
        }
    }
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showNotifications = defaults.bool(forKey: Keys.showNotifications)
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
