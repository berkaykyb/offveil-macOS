//
//  OffVeilColors.swift
//  OffVeil
//
//  Centralized color palette — eliminates magic color literals.
//

import SwiftUI

extension Color {
    // MARK: - Accent colors (active / inactive states)

    /// Primary active accent — bright green (0.09, 0.90, 0.58)
    static let ovAccentGreen = Color(red: 0.09, green: 0.90, blue: 0.58)

    /// Primary inactive accent — alert red (0.96, 0.28, 0.32)
    static let ovAccentRed = Color(red: 0.96, green: 0.28, blue: 0.32)

    /// Secondary active accent — deeper green (0.04, 0.68, 0.48)
    static let ovAccentGreenDeep = Color(red: 0.04, green: 0.68, blue: 0.48)

    /// Secondary inactive accent — deeper red (0.78, 0.14, 0.20)
    static let ovAccentRedDeep = Color(red: 0.78, green: 0.14, blue: 0.20)

    // MARK: - Brand / interactive

    /// Brand green for buttons, toggles, selections (0.14, 0.88, 0.68)
    static let ovBrandGreen = Color(red: 0.14, green: 0.88, blue: 0.68)

    /// Status dot green (0.11, 0.86, 0.62)
    static let ovStatusGreen = Color(red: 0.11, green: 0.86, blue: 0.62)

    // MARK: - Text

    /// Primary text — near-white (0.96, 0.98, 1.0)
    static let ovTextPrimary = Color(red: 0.96, green: 0.98, blue: 1.0)

    /// Secondary text — muted blue-grey (0.68, 0.75, 0.80)
    static let ovTextSecondary = Color(red: 0.68, green: 0.75, blue: 0.80)

    // MARK: - Error

    /// Error text color (0.96, 0.42, 0.44)
    static let ovErrorText = Color(red: 0.96, green: 0.42, blue: 0.44)

    /// Status accent error (1.0, 0.37, 0.41)
    static let ovErrorAccent = Color(red: 1.0, green: 0.37, blue: 0.41)

    // MARK: - Backgrounds

    /// Energy background dark top (0.03, 0.04, 0.08)
    static let ovDarkTop = Color(red: 0.03, green: 0.04, blue: 0.08)

    /// Energy background dark bottom (0.02, 0.02, 0.05)
    static let ovDarkBottom = Color(red: 0.02, green: 0.02, blue: 0.05)

    /// Classic background top (0.08, 0.09, 0.12)
    static let ovClassicTop = Color(red: 0.08, green: 0.09, blue: 0.12)

    /// Classic background bottom (0.05, 0.05, 0.08)
    static let ovClassicBottom = Color(red: 0.05, green: 0.05, blue: 0.08)
}
