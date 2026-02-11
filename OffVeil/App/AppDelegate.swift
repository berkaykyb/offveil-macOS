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
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Uygulama kapanmadan önce cleanup'ı senkron tamamla.
        restoreSystemOnExit()
        return .terminateNow
    }
    
    private func restoreSystemOnExit() {
        // Önce normal kapatma komutunu dene.
        _ = EngineService.shared.executeCommandSync("deactivate")

        // Sonra orphaned state/proxy/process kaldıysa garanti cleanup yap.
        let restoreResult = EngineService.shared.executeCommandSync("check_and_restore")
        switch restoreResult {
        case .success(let data):
            if let action = data["action"] as? String, action == "restored" {
                print("Exit cleanup: system settings restored")
            }
        case .failure(let error):
            print("Exit cleanup error:", error)
        }
    }
}
