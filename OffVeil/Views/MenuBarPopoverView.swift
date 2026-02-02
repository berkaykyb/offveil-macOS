//
//  MenuBarPopoverView.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI
struct MenuBarPopoverView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Büyük yuvarlak buton (placeholder)
            Button(action: {
                print("Buton tıklandı")
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "power")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Durum yazısı
            Text("Kapalı")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    MenuBarPopoverView()
}
