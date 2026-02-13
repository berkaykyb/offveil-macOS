//
//  ClassicBackgroundView.swift
//  OffVeil
//
//  Plain dark background without effects.
//

import SwiftUI

struct ClassicBackgroundView: View {
    let isActive: Bool

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
