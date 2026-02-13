//
//  ClassicBackgroundView.swift
//  OffVeil
//
//  Plain dark background without effects.
//

import SwiftUI

struct ClassicBackgroundView: View {
    let isActive: Bool

    private var accentColor: Color {
        isActive ? .ovAccentGreen : .ovAccentRed
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ovClassicTop,
                    Color.ovClassicBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle top glow reflecting active/inactive state
            RadialGradient(
                colors: [
                    accentColor.opacity(0.08),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.15),
                startRadius: 10,
                endRadius: 200
            )
            .animation(.easeInOut(duration: 0.6), value: isActive)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ClassicBackgroundView(isActive: false)
            .frame(width: 320, height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        ClassicBackgroundView(isActive: true)
            .frame(width: 320, height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
