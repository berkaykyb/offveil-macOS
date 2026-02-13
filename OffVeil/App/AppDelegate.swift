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
    private var statusChangeObserver: NSObjectProtocol?
    private let settings = SettingsManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menü bar item oluştur
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            updateStatusItemIcon(isActive: false)
        }
        
        // Popover oluştur
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.delegate = self
        refreshPopoverContent()
        observeProtectionStatusChanges()

        applyStartupPreferences()

        Task {
            await refreshStatusItemIcon()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            Task {
                await self.refreshStatusItemIcon()
            }
        }
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

    private func observeProtectionStatusChanges() {
        statusChangeObserver = NotificationCenter.default.addObserver(
            forName: .offveilProtectionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let isActive = notification.userInfo?[OffVeilNotificationUserInfoKey.isActive] as? Bool ?? false
            self.updateStatusItemIcon(isActive: isActive)
        }
    }

    private func updateStatusItemIcon(isActive: Bool) {
        guard let button = statusItem?.button else {
            return
        }

        button.title = ""
        button.imagePosition = .imageOnly

        if let image = loadStatusIcon(isActive: isActive) {
            // Menü bar yüksekliği 18pt. Orijinal oranı koruyarak ölçekle.
            let menuBarHeight: CGFloat = 18
            let aspectRatio = image.size.width / max(image.size.height, 1)
            let scaledWidth = menuBarHeight * aspectRatio
            image.size = NSSize(width: scaledWidth, height: menuBarHeight)
            image.isTemplate = false
            button.image = image
        } else {
            let fallback = NSImage(
                systemSymbolName: isActive ? "shield.fill" : "shield",
                accessibilityDescription: "OffVeil"
            )
            fallback?.isTemplate = true
            button.image = fallback
        }
    }

    private func loadStatusIcon(isActive: Bool) -> NSImage? {
        let fileName = isActive ? "menubar_active" : "menubar_inactive"

        // engine/ klasöründen doğrudan yükle (folder reference — garantili kopyalanır)
        if let resourcePath = Bundle.main.resourcePath {
            let fullPath = (resourcePath as NSString)
                .appendingPathComponent("engine")
                .appending("/\(fileName).png")
            if let image = NSImage(contentsOfFile: fullPath) {
                return image
            }
        }

        // Asset catalog fallback
        let catalogName = isActive ? "OffVeilLogoActive" : "OffVeilLogoInactive"
        if let image = NSImage(named: NSImage.Name(catalogName)) {
            return image
        }

        return nil
    }

    private func refreshStatusItemIcon() async {
        let statusResult = await EngineService.shared.getStatus()
        var isActive = false
        if case .success(let statusData) = statusResult {
            isActive = (statusData["status"] as? String) == "active"
        }

        await MainActor.run {
            self.updateStatusItemIcon(isActive: isActive)
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
                await self.refreshStatusItemIcon()
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

    deinit {
        if let observer = statusChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
