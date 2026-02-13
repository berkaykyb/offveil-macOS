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
    @State private var pulse = false
    
    var body: some View {
        Button(action: triggerToggle) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(activeGlowColor.opacity(0.42), lineWidth: 2.0)
                        .frame(width: 126, height: 126)
                        .blur(radius: 1.2)
                        .scaleEffect(pulse ? 1.06 : 0.96)
                        .opacity(pulse ? 0.18 : 0.55)
                        .animation(
                            .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(shellGradient)
                    .frame(width: 116, height: 116)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(shellBorderColor, lineWidth: 1.0)
                    )
                    .shadow(
                        color: isActive
                            ? Color(red: 0.04, green: 0.62, blue: 0.47).opacity(0.36)
                            : Color(red: 0.56, green: 0.12, blue: 0.19).opacity(0.30),
                        radius: 14,
                        x: 0,
                        y: 8
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isActive ? 0.26 : 0.11),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 92, height: 42)
                            .offset(x: -7, y: -26)
                            .blendMode(.screen)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(coreGradient)
                            .frame(width: 82, height: 82)
                            .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 4)
                    )
                    .scaleEffect(isPressed ? 0.94 : 1.0)
                    .offset(y: isPressed ? 1.2 : 0.0)

                Image(systemName: "power")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(iconColor)
                    .shadow(color: iconShadowColor, radius: 3, x: 0, y: 2)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1.0)
        .animation(.spring(response: 0.30, dampingFraction: 0.64), value: isActive)
        .onAppear {
            startPulseAnimationIfNeeded()
        }
        .onChange(of: isActive) { _ in
            startPulseAnimationIfNeeded()
        }
    }

    private var shellGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.92, blue: 0.72),
                    Color(red: 0.05, green: 0.67, blue: 0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.47, green: 0.13, blue: 0.19),
                Color(red: 0.26, green: 0.06, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var coreGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.88, blue: 0.68),
                    Color(red: 0.03, green: 0.60, blue: 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.40, green: 0.10, blue: 0.16),
                Color(red: 0.22, green: 0.05, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shellBorderColor: Color {
        if isActive {
            return Color(red: 0.64, green: 1.00, blue: 0.88).opacity(0.90)
        }
        return Color(red: 1.0, green: 0.53, blue: 0.59).opacity(0.72)
    }

    private var activeGlowColor: Color {
        Color(red: 0.28, green: 1.00, blue: 0.80)
    }

    private var iconColor: Color {
        isActive ? Color.black.opacity(0.82) : Color.white.opacity(0.90)
    }

    private var iconShadowColor: Color {
        isActive
            ? Color(red: 0.00, green: 0.32, blue: 0.24).opacity(0.35)
            : Color.black.opacity(0.40)
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

    private func startPulseAnimationIfNeeded() {
        pulse = false
        guard isActive else { return }
        DispatchQueue.main.async {
            pulse = true
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
