//
//  PowerButton.swift
//  OffVeil
//
//  Created by Berkay KAYABAŞI on 2.02.2026.
//

import SwiftUI

struct PowerButton: View {
    @Binding var isActive: Bool
    var isDisabled: Bool = false
    var onToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: triggerToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(mainFillColor)
                    .frame(width: 148, height: 148)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(borderColor, lineWidth: 1.5)
                    )
                    .shadow(
                        color: isActive ? Color(red: 0.05, green: 0.50, blue: 0.40).opacity(0.35) : Color.black.opacity(0.25),
                        radius: 16,
                        x: 0,
                        y: 10
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)

                Image(systemName: "power")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(iconColor)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }

    private var mainFillColor: Color {
        if isActive {
            return Color(red: 0.06, green: 0.75, blue: 0.58)
        }
        return Color(red: 0.14, green: 0.16, blue: 0.20)
    }

    private var borderColor: Color {
        if isActive {
            return Color(red: 0.16, green: 0.90, blue: 0.70).opacity(0.9)
        }
        return Color.white.opacity(0.12)
    }

    private var iconColor: Color {
        isActive ? Color.black.opacity(0.80) : Color.white.opacity(0.82)
    }

    private func triggerToggle() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.64)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.64)) {
                isPressed = false
            }
            onToggle()
        }
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
