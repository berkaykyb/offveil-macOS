//
//  OffVeilApp.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

@main
struct OffVeilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Fail-safe: Uygulama açıldığında orphaned state varsa DNS'i geri yükle
        Task {
            await performFailSafeCheck()
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
    
    private func performFailSafeCheck() async {
        let result = await EngineService.shared.executeCommand("check_and_restore")
        switch result {
        case .success(let data):
            if let action = data["action"] as? String, action == "restored" {
                print("Fail-safe: DNS restored from previous session")
            }
        case .failure(let error):
            print("Fail-safe check error:", error)
        }
    }
}
