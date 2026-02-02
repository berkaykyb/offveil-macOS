//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @State private var isActive = false
    
    var body: some View {
        VStack(spacing: 20) {
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
