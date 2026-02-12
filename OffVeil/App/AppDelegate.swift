//
//  AppDelegate.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
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
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.delegate = self
        refreshPopoverContent()
    }
    
    @objc func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                // Her açılışta içeriği yenile: ayarlar ekranında takılı kalmasın.
                refreshPopoverContent()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                installEventMonitors()
            }
        }
    }

    private func refreshPopoverContent() {
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
    }

    private func closePopover() {
        popover?.performClose(nil)
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePopover()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self else { return event }
            guard let popover = self.popover, popover.isShown else { return event }
            let popoverWindow = popover.contentViewController?.view.window

            // Popover içindeki tıklamalarda kapanma istemiyoruz.
            if event.window === popoverWindow {
                return event
            }

            self.closePopover()
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitors()
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
