//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @State private var isActive = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @StateObject private var ispManager = ISPManager.shared
    
    var body: some View {
        ZStack {
            // Ana Panel
            if !showSettings {
                mainView
                    .transition(.move(edge: .leading))
            }
            
            // Ayarlar Panel
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
            // Popover kapanınca ayarlar ekranında kalmasın.
            showSettings = false
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 20) {
            // Üst bar: ISS + Ayarlar
            HStack {
                // ISS göstergesi
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(ispManager.ispName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .opacity(ispManager.isDetecting ? 0.5 : 1.0)
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Ayarlar butonu
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Power Button
            PowerButton(isActive: $isActive) {
                Task {
                    isProcessing = true
                    errorMessage = nil
                    defer { isProcessing = false }

                    if isActive {
                        let result = await EngineService.shared.executeCommand("deactivate")
                        switch result {
                        case .success(let data):
                            if data["success"] as? Bool == true {
                                isActive = false
                            } else {
                                errorMessage = (data["error"] as? String) ?? "Kapatma başarısız"
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        let result = await EngineService.shared.executeCommand("activate")
                        switch result {
                        case .success(let data):
                            if data["success"] as? Bool == true {
                                isActive = true
                                if let normalizedISP = data["isp_normalized"] as? String,
                                   !normalizedISP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    ispManager.ispName = normalizedISP
                                } else if let detectedISP = data["isp_detected"] as? String,
                                          !detectedISP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    ispManager.ispName = detectedISP
                                }
                            } else {
                                errorMessage = (data["error"] as? String) ?? "Aktivasyon başarısız"
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .disabled(isProcessing)
            
            // Durum yazısı
            Text(isActive ? "Aktif" : "Kapalı")
                .font(.title2)
                .foregroundColor(isActive ? .green : .secondary)
                .animation(.easeInOut, value: isActive)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func refreshStatus() async {
        let result = await EngineService.shared.getStatus()
        guard case .success(let data) = result else { return }
        guard data["success"] as? Bool == true else { return }
        isActive = (data["status"] as? String) == "active"
    }
}

#Preview {
    MenuBarPopoverView()
}
