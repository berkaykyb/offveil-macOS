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

    private let updateURLString = "https://github.com/berkaykyb/offveil-macOS/releases"
    
    var body: some View {
        ZStack {
            if !showSettings {
                mainView
                    .transition(.move(edge: .leading))
            }
            
            if showSettings {
                SettingsView(isPresented: $showSettings)
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
        .onDisappear {
            showSettings = false
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)

            Spacer(minLength: 20)

            PowerButton(isActive: $isActive, isDisabled: isProcessing) {
                Task { await toggleProtection() }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                Text(isActive ? "Protection Active" : "Protection Inactive")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.9)
                    .lineLimit(1)
            }
            .padding(.top, 14)

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
                Circle()
                    .fill(Color(red: 0.11, green: 0.86, blue: 0.62))
                    .frame(width: 6, height: 6)
                Text(ispManager.ispName)
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
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.05, blue: 0.08),
                        Color(red: 0.03, green: 0.04, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color(red: 0.08, green: 0.56, blue: 0.45).opacity(0.24))
                    .frame(width: 220, height: 220)
                    .offset(x: -130, y: -160)
            }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandIconView()

            VStack(alignment: .leading, spacing: 2) {
                Text("offveil")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundColor(primaryTextColor)
                Text("Secure Tunnel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryTextColor.opacity(0.86))
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: {
                Task { await clearAll() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise.circle")
                    Text("Clear All")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.95, green: 0.42, blue: 0.42))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)

            Button(action: openUpdatesPage) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.app")
                    Text("Check updates")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(primaryTextColor.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                    } else if let detectedISP = data["isp_detected"] as? String,
                              !detectedISP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ispManager.ispName = detectedISP
                    }
                }
            } else {
                errorMessage = (data["error"] as? String) ?? "Operation failed"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        await refreshStatus()
    }

    @MainActor
    private func clearAll() async {
        if isProcessing {
            return
        }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        _ = await EngineService.shared.executeCommand("deactivate")
        let restoreResult = await EngineService.shared.executeCommand("check_and_restore")
        switch restoreResult {
        case .success(let data):
            let success = data["success"] as? Bool ?? false
            if !success {
                errorMessage = (data["message"] as? String) ?? "Reset failed"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        ispManager.invalidateCache()
        ispManager.detectISP()
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
    }
}

private struct BrandIconView: View {
    private let brandImageName = "OffVeilLogo"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.06, green: 0.21, blue: 0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.13, green: 0.56, blue: 0.46), lineWidth: 1)
                )

            if let image = NSImage(named: brandImageName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "shield")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.88, blue: 0.66))
            }
        }
    }
}

#Preview {
    MenuBarPopoverView()
}
