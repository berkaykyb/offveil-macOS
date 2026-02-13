//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @State private var isActive = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @StateObject private var ispManager = ISPManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    private let updateURLString = "https://github.com/berkaykyb/offveil-macOS/releases"
    
    var body: some View {
        ZStack {
            if !showSettings {
                mainView
                    .transition(.move(edge: .leading))
            }
            
            if showSettings {
                SettingsView(isPresented: $showSettings, isActive: $isActive)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSettings)
        .onAppear {
            ispManager.detectISP()
            Task {
                await refreshStatus()
            }
        }
        .onChange(of: isActive) { _ in
            publishProtectionState()
        }
        .onDisappear {
            showSettings = false
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)

            Spacer(minLength: 16)

            PowerButton(isActive: $isActive, isDisabled: isProcessing) {
                Task { await toggleProtection() }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isActive ? Color(red: 0.11, green: 0.86, blue: 0.62) : Color(red: 0.96, green: 0.28, blue: 0.32))
                        .frame(width: 8, height: 8)
                    Text(isActive ? localized(.protectionActive) : localized(.protectionInactive))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                }
                Text(isActive ? "Your connection is secured" : "Tap to enable protection")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.top, 10)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.96, green: 0.42, blue: 0.44))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            Spacer(minLength: 24)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(statusAccent.opacity(0.42))
                        .frame(width: 16, height: 16)
                        .blur(radius: 4)
                    Circle()
                        .fill(statusAccent)
                        .frame(width: 7, height: 7)
                }
                .animation(.easeInOut(duration: 0.25), value: hasStatusError)
                Text(localizedISPName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)
                    .opacity(ispManager.isDetecting ? 0.55 : 1.0)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.08))

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 320, height: 450)
        .background(
            ThemedBackgroundView(isActive: isActive)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            let logoName = isActive ? "OffVeilMenuActive" : "OffVeilMenuInactive"
            Image(logoName)
                .resizable()
                .scaledToFit()
                .frame(height: 28)

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryTextColor.opacity(0.72))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button(action: {
                Task { await cleanup() }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(localized(.cleanup))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryTextColor)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)

            Spacer()

            Button(action: openUpdatesPage) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle")
                    Text(localized(.checkUpdates))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryTextColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
        }
    }

    private var primaryTextColor: Color {
        Color(red: 0.96, green: 0.98, blue: 1.0)
    }

    private var secondaryTextColor: Color {
        Color(red: 0.68, green: 0.75, blue: 0.80)
    }

    private var hasStatusError: Bool {
        if errorMessage != nil {
            return true
        }
        return ispManager.ispName == "Detection failed"
    }

    private var statusAccent: Color {
        if hasStatusError {
            return Color(red: 1.0, green: 0.37, blue: 0.41)
        }
        return Color(red: 0.11, green: 0.86, blue: 0.62)
    }

    private var localizedISPName: String {
        switch ispManager.ispName {
        case "Detecting...":
            return localized(.ispDetecting)
        case "Unknown":
            return localized(.ispUnknown)
        case "Detection failed":
            return localized(.ispDetectionFailed)
        default:
            return ispManager.ispName
        }
    }

    private func localized(_ key: L10nKey) -> String {
        AppLocalizer.text(key, language: settings.appLanguage)
    }

    private func publishProtectionState() {
        NotificationCenter.default.post(
            name: .offveilProtectionStatusChanged,
            object: nil,
            userInfo: [OffVeilNotificationUserInfoKey.isActive: isActive]
        )
    }

    @MainActor
    private func toggleProtection() async {
        if isProcessing {
            return
        }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let command = isActive ? "deactivate" : "activate"
        let result = await EngineService.shared.executeCommand(command)

        switch result {
        case .success(let data):
            if data["success"] as? Bool == true {
                isActive = !isActive
                if isActive {
                    if let normalizedISP = data["isp_normalized"] as? String,
                       !normalizedISP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ispManager.ispName = normalizedISP
                    }
                }
            } else {
                errorMessage = (data["error"] as? String) ?? localized(.operationFailed)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        await refreshStatus()
    }

    @MainActor
    private func cleanup() async {
        if isProcessing {
            return
        }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        // 1. Deactivate if currently active
        _ = await EngineService.shared.executeCommand("deactivate")

        // 2. Full system cleanup (DNS, proxy, orphan processes)
        let cleanupResult = await EngineService.shared.executeCommand("cleanup")
        switch cleanupResult {
        case .success(let data):
            let success = data["success"] as? Bool ?? false
            if !success {
                errorMessage = (data["message"] as? String) ?? localized(.resetFailed)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        // 3. Fallback: also run check_and_restore
        _ = await EngineService.shared.executeCommand("check_and_restore")

        ispManager.invalidateCache()
        ispManager.detectISP()
        isActive = false
        publishProtectionState()
        await refreshStatus()
    }

    private func openUpdatesPage() {
        guard let url = URL(string: updateURLString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func refreshStatus() async {
        let result = await EngineService.shared.getStatus()
        guard case .success(let data) = result else { return }
        guard data["success"] as? Bool == true else { return }
        isActive = (data["status"] as? String) == "active"
        publishProtectionState()
    }
}

#Preview {
    MenuBarPopoverView()
}
