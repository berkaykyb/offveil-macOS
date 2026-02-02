//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @State private var isActive = false
    @State private var showSettings = false
    
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
    }
    
    private var mainView: some View {
        VStack(spacing: 20) {
            // Ayarlar butonu
            HStack {
                Spacer()
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
                isActive.toggle()
                print("Durum değişti: \(isActive ? "Aktif" : "Kapalı")")
            }
            
            // Durum yazısı
            Text(isActive ? "Aktif" : "Kapalı")
                .font(.title2)
                .foregroundColor(isActive ? .green : .secondary)
                .animation(.easeInOut, value: isActive)
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    MenuBarPopoverView()
}
