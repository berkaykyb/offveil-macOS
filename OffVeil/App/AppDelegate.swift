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
    private let settings = SettingsManager.shared
    
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

        applyStartupPreferences()
    }
    
    @objc func statusItemClicked() {
        guard let popover = popover else { return }

        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func refreshPopoverContent() {
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
    }

    private func closePopover() {
        popover?.performClose(nil)
        removeEventMonitors()
    }

    private func openPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        guard !popover.isShown else { return }

        // Her açılışta içeriği yenile: ayarlar ekranında takılı kalmasın.
        refreshPopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installEventMonitors()
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

    private func applyStartupPreferences() {
        guard settings.launchAtLogin else {
            return
        }

        Task.detached { [weak self] in
            guard let self = self else { return }

            if self.settings.autoActivateOnLaunch {
                await self.activateProtectionIfNeeded()
            }

            guard !self.settings.startHiddenOnLaunch else {
                return
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                self.openPopover()
            }
        }
    }

    private func activateProtectionIfNeeded() async {
        let statusResult = await EngineService.shared.getStatus()
        guard case .success(let statusData) = statusResult else {
            return
        }

        let isActive = (statusData["status"] as? String) == "active"
        if isActive {
            return
        }

        _ = await EngineService.shared.executeCommand("activate")
    }
}
