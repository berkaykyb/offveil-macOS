//
//  SettingsView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                
                Spacer()
                
                Color.clear
                    .frame(width: 20)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Settings List
            VStack(alignment: .leading, spacing: 0) {
                // Başlangıçta Başlat
                SettingsToggleRow(
                    title: "Launch at Login",
                    isOn: $settings.launchAtLogin
                )
                
                Divider()
                    .padding(.leading, 16)
                
                // Bildirimler
                SettingsToggleRow(
                    title: "Notifications",
                    isOn: $settings.showNotifications
                )
                
                Divider()
                    .padding(.leading, 16)
                
                // About
                Button(action: {
                    print("About tapped")
                }) {
                    HStack {
                        Text("About")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 16)
            }
            
            Spacer()
            
            // Version
            Text("OffVeil v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .frame(width: 320, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}
