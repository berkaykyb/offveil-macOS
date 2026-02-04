//
//  AppDelegate.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menü bar item oluştur
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "OffVeil")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        // Popover oluştur
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
    }
    
    @objc func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Uygulama kapanırken DNS'i geri yükle
        Task {
            await restoreDNSOnExit()
        }
    }
    
    private func restoreDNSOnExit() async {
        let result = await EngineService.shared.executeCommand("check_and_restore")
        switch result {
        case .success(let data):
            if let action = data["action"] as? String, action == "restored" {
                print("Exit cleanup: DNS restored successfully")
            }
        case .failure(let error):
            print("Exit cleanup error:", error)
        }
    }
}
