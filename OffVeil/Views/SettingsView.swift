import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = SettingsManager.shared

    @State private var screen: SettingsScreen = .main
    @State private var pendingLanguage: AppLanguage = SettingsManager.shared.appLanguage

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.top, 12)

            Group {
                switch screen {
                case .main:
                    settingsMainContent
                case .about:
                    settingsAboutContent
                case .licenses:
                    settingsLicensesContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 320, height: 450)
        .background(SettingsGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            pendingLanguage = settings.appLanguage
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var settingsHeader: some View {
        HStack(spacing: 10) {
            Button(action: backOrClose) {
                Image(systemName: screen == .main ? "xmark" : "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(PlainButtonStyle())

            Text(screenTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            Spacer()
        }
    }

    private var settingsMainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                SettingsSectionCard(title: localized(.startupSection)) {
                    SettingsToggleRow(
                        title: localized(.launchAtLoginTitle),
                        subtitle: localized(.launchAtLoginSubtitle),
                        isOn: launchAtLoginBinding
                    )

                    if settings.launchAtLogin {
                        VStack(spacing: 0) {
                            Divider().overlay(Color.white.opacity(0.08))

                            SettingsToggleRow(
                                title: localized(.autoActiveTitle),
                                subtitle: localized(.autoActiveSubtitle),
                                isOn: $settings.autoActivateOnLaunch,
                                indented: true
                            )

                            Divider().overlay(Color.white.opacity(0.08))

                            SettingsToggleRow(
                                title: localized(.startHiddenTitle),
                                subtitle: localized(.startHiddenSubtitle),
                                isOn: $settings.startHiddenOnLaunch,
                                indented: true
                            )
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            )
                        )
                    }
                }

                SettingsSectionCard(title: localized(.languageSection)) {
                    LanguagePickerRow(
                        currentLanguage: settings.appLanguage,
                        pendingLanguage: $pendingLanguage,
                        applyAction: applyLanguageSelection
                    )
                }

                SettingsSectionCard(title: localized(.infoSection)) {
                    SettingsNavigationRow(
                        title: localized(.aboutRowTitle),
                        subtitle: localized(.aboutRowSubtitle)
                    ) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            screen = .about
                        }
                    }
                }
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { newValue in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    settings.launchAtLogin = newValue
                }
            }
        )
    }

    private var settingsAboutContent: some View {
        VStack(spacing: 12) {
            SettingsSectionCard(title: localized(.applicationSection)) {
                HStack(spacing: 12) {
                    AppMark()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("OffVeil")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        Text(localized(.secureTunnel))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider().overlay(Color.white.opacity(0.08))

                SettingsValueRow(title: localized(.versionLabel), value: appVersion)

                Divider().overlay(Color.white.opacity(0.08))

                SettingsValueRow(title: localized(.buildLabel), value: appBuild)
            }

            SettingsSectionCard(title: localized(.legalSection)) {
                SettingsNavigationRow(
                    title: localized(.openSourceRowTitle),
                    subtitle: localized(.openSourceRowSubtitle)
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        screen = .licenses
                    }
                }
            }

            Spacer()
        }
    }

    private var settingsLicensesContent: some View {
        VStack(spacing: 10) {
            SettingsSectionCard(title: localized(.openSourceSection)) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SpoofDPI")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        Text(localized(.spoofDpiBody))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.70))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 230)
            }

            Spacer()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func backOrClose() {
        if screen == .main {
            isPresented = false
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            screen = screen.parent ?? .main
        }
    }

    private func applyLanguageSelection() {
        guard pendingLanguage != settings.appLanguage else {
            return
        }
        settings.appLanguage = pendingLanguage
    }

    private func localized(_ key: L10nKey) -> String {
        AppLocalizer.text(key, language: settings.appLanguage)
    }

    private var screenTitle: String {
        switch screen {
        case .main:
            return localized(.settingsTitle)
        case .about:
            return localized(.aboutTitle)
        case .licenses:
            return localized(.openSourceLicensesTitle)
        }
    }
}

private enum SettingsScreen {
    case main
    case about
    case licenses

    var parent: SettingsScreen? {
        switch self {
        case .main:
            return nil
        case .about:
            return .main
        case .licenses:
            return .about
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var indented: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(red: 0.16, green: 0.84, blue: 0.66))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            indented
                ? Color.white.opacity(0.03)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct LanguagePickerRow: View {
    let currentLanguage: AppLanguage
    @Binding var pendingLanguage: AppLanguage
    let applyAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.text(.appLanguageTitle, language: currentLanguage))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button(action: { pendingLanguage = language }) {
                        Text(language.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(language == pendingLanguage ? Color.black.opacity(0.82) : .white.opacity(0.80))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(
                                        language == pendingLanguage
                                            ? Color(red: 0.14, green: 0.88, blue: 0.68)
                                            : Color.white.opacity(0.08)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)

            if pendingLanguage != currentLanguage {
                Button(action: applyAction) {
                    Text(AppLocalizer.text(.applyLanguageButton, language: currentLanguage))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.14, green: 0.88, blue: 0.68))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)
                .frame(height: 4)
                .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: pendingLanguage)
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.44))
                .tracking(0.7)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.10),
                    Color(red: 0.03, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 170
                    )
                )
                .frame(width: 320, height: 170)
                .offset(x: -18, y: -180)
                .blur(radius: 2.5)

            Circle()
                .fill(Color(red: 0.18, green: 0.55, blue: 0.88).opacity(0.20))
                .frame(width: 280, height: 280)
                .offset(x: -145, y: -120)
                .blur(radius: 8)

            Circle()
                .fill(Color(red: 0.10, green: 0.20, blue: 0.34).opacity(0.28))
                .frame(width: 220, height: 220)
                .offset(x: 150, y: 140)
                .blur(radius: 12)
        }
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .frame(width: 34, height: 34)

            if let image = NSImage(named: NSImage.Name("OffVeilLogo")) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "shield")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}
