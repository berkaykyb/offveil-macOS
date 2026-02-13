//
//  EnergyBackgroundView.swift
//  OffVeil
//
//  Animated energy vein / lightning background.
//  Red glow when inactive, green glow when active.
//

import SwiftUI

// MARK: - Main Background

struct EnergyBackgroundView: View {
    let isActive: Bool

    @State private var phase: CGFloat = 0
    @State private var pulse: CGFloat = 0
    @State private var isAnimating = false

    private var accentColor: Color {
        isActive
            ? Color(red: 0.09, green: 0.90, blue: 0.58)
            : Color(red: 0.96, green: 0.28, blue: 0.32)
    }

    private var accentSecondary: Color {
        isActive
            ? Color(red: 0.04, green: 0.68, blue: 0.48)
            : Color(red: 0.78, green: 0.14, blue: 0.20)
    }

    var body: some View {
        ZStack {
            // Deep dark base
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glow at center-top
            RadialGradient(
                colors: [
                    accentColor.opacity(0.10),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 10,
                endRadius: 200
            )
            .animation(.easeInOut(duration: 0.8), value: isActive)

            // Energy veins layer (single draw + glow combined)
            EnergyVeinsShape(phase: phase)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.55),
                            accentSecondary.opacity(0.30),
                            accentColor.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .blur(radius: 0.6)
                .animation(.easeInOut(duration: 0.8), value: isActive)

            // Bloom glow for primary veins
            EnergyVeinsShape(phase: phase)
                .stroke(
                    accentColor.opacity(0.18 + pulse * 0.10),
                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                )
                .blur(radius: 5)
                .animation(.easeInOut(duration: 0.8), value: isActive)

            // Secondary vein set
            EnergyVeinsShapeAlt(phase: phase * 0.7)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentSecondary.opacity(0.35),
                            accentColor.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
                .blur(radius: 0.4)
                .animation(.easeInOut(duration: 0.8), value: isActive)

            // Corner accent glow - top left
            Circle()
                .fill(accentColor.opacity(0.12 + pulse * 0.05))
                .frame(width: 180, height: 180)
                .offset(x: -120, y: -180)
                .blur(radius: 25)
                .animation(.easeInOut(duration: 0.8), value: isActive)

            // Corner accent glow - bottom right
            Circle()
                .fill(accentSecondary.opacity(0.08 + pulse * 0.04))
                .frame(width: 140, height: 140)
                .offset(x: 120, y: 160)
                .blur(radius: 20)
                .animation(.easeInOut(duration: 0.8), value: isActive)

            // Top edge light streak
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 80)
                .offset(x: 0, y: -200)
                .blur(radius: 2)
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .drawingGroup() // Flatten layers into single GPU texture
    }

    private func startAnimations() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            phase = 1.0
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            pulse = 1.0
        }
    }

    private func stopAnimations() {
        isAnimating = false
        // Reset animation state so it restarts cleanly on next appear
        phase = 0
        pulse = 0
    }
}

// MARK: - Primary Energy Veins Shape

struct EnergyVeinsShape: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Vein 1: top-left flowing down-right
        let v1Offset = sin(phase * .pi * 2) * 12
        path.move(to: CGPoint(x: 0, y: h * 0.15))
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.40),
            control1: CGPoint(x: w * 0.08 + v1Offset, y: h * 0.18),
            control2: CGPoint(x: w * 0.22 - v1Offset * 0.5, y: h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.72),
            control1: CGPoint(x: w * 0.42 + v1Offset * 0.3, y: h * 0.50),
            control2: CGPoint(x: w * 0.20 - v1Offset * 0.4, y: h * 0.64)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.90),
            control1: CGPoint(x: w * 0.10 + v1Offset * 0.2, y: h * 0.78),
            control2: CGPoint(x: w * 0.04, y: h * 0.86)
        )

        // Vein 2: top flowing to center-right
        let v2Offset = cos(phase * .pi * 2) * 10
        path.move(to: CGPoint(x: w * 0.45, y: 0))
        path.addCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.30),
            control1: CGPoint(x: w * 0.48 + v2Offset, y: h * 0.08),
            control2: CGPoint(x: w * 0.55 - v2Offset * 0.6, y: h * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.55),
            control1: CGPoint(x: w * 0.65 + v2Offset * 0.4, y: h * 0.38),
            control2: CGPoint(x: w * 0.78, y: h * 0.48 + v2Offset * 0.3)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.65),
            control1: CGPoint(x: w * 0.90, y: h * 0.58),
            control2: CGPoint(x: w * 0.96, y: h * 0.62)
        )

        // Vein 3: small branch from vein 1
        let v3Offset = sin(phase * .pi * 2 + 1.5) * 8
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.35))
        path.addCurve(
            to: CGPoint(x: w * 0.10, y: h * 0.52),
            control1: CGPoint(x: w * 0.18 + v3Offset * 0.3, y: h * 0.40),
            control2: CGPoint(x: w * 0.12, y: h * 0.47 + v3Offset * 0.2)
        )

        // Vein 4: right side flowing down
        let v4Offset = sin(phase * .pi * 2 + 2.8) * 9
        path.move(to: CGPoint(x: w, y: h * 0.20))
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.45),
            control1: CGPoint(x: w * 0.94 - v4Offset * 0.5, y: h * 0.28),
            control2: CGPoint(x: w * 0.82 + v4Offset * 0.3, y: h * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.80),
            control1: CGPoint(x: w * 0.70 - v4Offset * 0.2, y: h * 0.55),
            control2: CGPoint(x: w * 0.85 + v4Offset * 0.4, y: h * 0.70)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h),
            control1: CGPoint(x: w * 0.93, y: h * 0.88),
            control2: CGPoint(x: w * 0.97, y: h * 0.95)
        )

        return path
    }
}

// MARK: - Secondary Energy Veins Shape

struct EnergyVeinsShapeAlt: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Alt vein 1: bottom-left upward
        let a1 = cos(phase * .pi * 2 + 0.8) * 10
        path.move(to: CGPoint(x: 0, y: h * 0.70))
        path.addCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.50),
            control1: CGPoint(x: w * 0.06 + a1 * 0.4, y: h * 0.65),
            control2: CGPoint(x: w * 0.20 - a1 * 0.3, y: h * 0.54)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.68),
            control1: CGPoint(x: w * 0.38, y: h * 0.46 + a1 * 0.2),
            control2: CGPoint(x: w * 0.48 + a1 * 0.3, y: h * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h),
            control1: CGPoint(x: w * 0.58, y: h * 0.78),
            control2: CGPoint(x: w * 0.52, y: h * 0.92)
        )

        // Alt vein 2: top-right diagonal
        let a2 = sin(phase * .pi * 2 + 2.0) * 7
        path.move(to: CGPoint(x: w * 0.70, y: 0))
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.20),
            control1: CGPoint(x: w * 0.68 + a2 * 0.3, y: h * 0.06),
            control2: CGPoint(x: w * 0.58 - a2 * 0.2, y: h * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.38),
            control1: CGPoint(x: w * 0.52 + a2 * 0.4, y: h * 0.26),
            control2: CGPoint(x: w * 0.62, y: h * 0.33 + a2 * 0.2)
        )

        // Alt vein 3: center small branch
        let a3 = cos(phase * .pi * 2 + 3.5) * 6
        path.move(to: CGPoint(x: w * 0.40, y: h * 0.82))
        path.addCurve(
            to: CGPoint(x: w * 0.25, y: h),
            control1: CGPoint(x: w * 0.36 + a3 * 0.3, y: h * 0.88),
            control2: CGPoint(x: w * 0.28 - a3 * 0.2, y: h * 0.95)
        )

        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        EnergyBackgroundView(isActive: false)
            .frame(width: 320, height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 20))

        EnergyBackgroundView(isActive: true)
            .frame(width: 320, height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
