//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @State private var isActive = UserDefaults.standard.bool(forKey: "lastKnownProtectionState")
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var resetConfirmPending = false
    @State private var quitConfirmPending = false
    @StateObject private var updateManager = UpdateManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
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
            showSettings = false
            Task {
                await refreshStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .offveilPopoverDidOpen)) { _ in
            showSettings = false
        }
        .onChange(of: isActive) { _ in
            publishProtectionState()
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
                        .fill(isActive ? Color.ovStatusGreen : Color.ovAccentRed)
                        .frame(width: 8, height: 8)
                    Text(isActive ? localized(.protectionActive) : localized(.protectionInactive))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                }
                Text(isActive ? localized(.connectionSecured) : localized(.tapToEnable))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.top, 10)

            if let msg = errorMessage ?? updateManager.errorMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.ovErrorText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            Spacer(minLength: 24)



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

            Button(action: {
                if quitConfirmPending {
                    NSApplication.shared.terminate(nil)
                } else {
                    quitConfirmPending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        quitConfirmPending = false
                    }
                }
            }) {
                Image(systemName: quitConfirmPending ? "exclamationmark.triangle" : "power")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(quitConfirmPending ? .ovErrorText : primaryTextColor.opacity(0.50))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(quitConfirmPending ? Color.ovErrorText.opacity(0.12) : Color.white.opacity(0.06))
                    )
                    .animation(.easeInOut(duration: 0.2), value: quitConfirmPending)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button(action: {
                if resetConfirmPending {
                    resetConfirmPending = false
                    Task { await reset() }
                } else {
                    resetConfirmPending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        resetConfirmPending = false
                    }
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: resetConfirmPending ? "exclamationmark.triangle" : "arrow.counterclockwise")
                    Text(resetConfirmPending ? localized(.resetConfirm) : localized(.reset))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(resetConfirmPending ? .ovErrorText : secondaryTextColor)
                .animation(.easeInOut(duration: 0.2), value: resetConfirmPending)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)

            Spacer()

            updateButton
        }
    }

    @ViewBuilder
    private var updateButton: some View {
        if updateManager.isDownloading {
            // Downloading state — show progress
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("\(Int(updateManager.downloadProgress * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .monospacedDigit()
            }
        } else if updateManager.updateAvailable {
            // Update ready to download
            Button(action: {
                Task { await updateManager.downloadAndInstall() }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.to.line.compact")
                    Text(localized(.updateAvailable))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.ovAccentGreen)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // Default: check for updates
            Button(action: {
                Task { await updateManager.checkForUpdate() }
            }) {
                HStack(spacing: 5) {
                    if updateManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text(localized(.checkUpdates))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryTextColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing || updateManager.isChecking)
        }
    }

    private var primaryTextColor: Color { .ovTextPrimary }

    private var secondaryTextColor: Color { .ovTextSecondary }



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
                NotificationService.shared.sendProtectionNotification(isActive: isActive)
            } else {
                errorMessage = (data["error"] as? String) ?? localized(.operationFailed)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        await refreshStatus()
    }

    @MainActor
    private func reset() async {
        if isProcessing {
            return
        }

        isProcessing = true
        errorMessage = nil
        updateManager.errorMessage = nil
        defer { isProcessing = false }

        // 1. Deactivate if currently active
        _ = await EngineService.shared.executeCommand("deactivate")

        // 2. Full system reset (DNS, proxy, orphan processes)
        let resetResult = await EngineService.shared.executeCommand("reset")
        switch resetResult {
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

        isActive = false
        publishProtectionState()
        await refreshStatus()
    }

    @MainActor
    private func refreshStatus() async {
        let result = await EngineService.shared.getStatus()
        guard case .success(let data) = result else { return }
        guard data["success"] as? Bool == true else { return }
        isActive = (data["status"] as? String) == "active"
        UserDefaults.standard.set(isActive, forKey: "lastKnownProtectionState")
        publishProtectionState()
    }
}

#Preview {
    MenuBarPopoverView()
}
