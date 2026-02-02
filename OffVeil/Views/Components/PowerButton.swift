//
//  PowerButton.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct PowerButton: View {
    @Binding var isActive: Bool
    var onToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                onToggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                Circle()
                    .stroke(isActive ? Color.green : Color.gray, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                Image(systemName: "power")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(isActive ? .green : .gray)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
}

#Preview {
    VStack(spacing: 30) {
        PowerButton(isActive: .constant(false)) {
            print("Off")
        }
        
        PowerButton(isActive: .constant(true)) {
            print("On")
        }
    }
    .frame(width: 300, height: 400)
}
