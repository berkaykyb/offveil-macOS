//
//  ThemedBackgroundView.swift
//  OffVeil
//
//  Selects the correct background based on the user's theme preference.
//

import SwiftUI

struct ThemedBackgroundView: View {
    let isActive: Bool
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Group {
            switch settings.appTheme {
            case .energy:
                EnergyBackgroundView(isActive: isActive)
            case .classic:
                ClassicBackgroundView(isActive: isActive)
            }
        }
    }
}
