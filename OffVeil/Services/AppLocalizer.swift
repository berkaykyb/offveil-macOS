import Foundation

enum L10nKey: String {
    case settingsTitle
    case aboutTitle
    case openSourceLicensesTitle

    case startupSection
    case launchAtLoginTitle
    case launchAtLoginSubtitle
    case autoActiveTitle
    case autoActiveSubtitle
    case startHiddenTitle
    case startHiddenSubtitle

    case languageSection
    case appLanguageTitle
    case applyLanguageButton

    case infoSection
    case aboutRowTitle
    case aboutRowSubtitle

    case applicationSection
    case secureTunnel
    case versionLabel
    case buildLabel

    case legalSection
    case openSourceRowTitle
    case openSourceRowSubtitle

    case openSourceSection
    case spoofDpiBody

    case protectionActive
    case protectionInactive
    case clearAll
    case checkUpdates
    case operationFailed
    case resetFailed

    case ispDetecting
    case ispUnknown
    case ispDetectionFailed
}

struct AppLocalizer {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        translations[language]?[key]
            ?? translations[.en]?[key]
            ?? key.rawValue
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .en: [
            .settingsTitle: "Settings",
            .aboutTitle: "About",
            .openSourceLicensesTitle: "Open Source Licenses",

            .startupSection: "Startup",
            .launchAtLoginTitle: "Launch at Login",
            .launchAtLoginSubtitle: "Start OffVeil when macOS starts",
            .autoActiveTitle: "Auto Active on Launch",
            .autoActiveSubtitle: "Automatically enable protection on startup",
            .startHiddenTitle: "Start Hidden",
            .startHiddenSubtitle: "Open only in menu bar without interrupting",

            .languageSection: "Language",
            .appLanguageTitle: "App Language",
            .applyLanguageButton: "Apply Language",

            .infoSection: "Information",
            .aboutRowTitle: "About",
            .aboutRowSubtitle: "Version, credits and legal info",

            .applicationSection: "Application",
            .secureTunnel: "Secure Tunnel",
            .versionLabel: "Version",
            .buildLabel: "Build",

            .legalSection: "Legal",
            .openSourceRowTitle: "Open Source Licenses",
            .openSourceRowSubtitle: "Third-party components and licenses",

            .openSourceSection: "Open Source",
            .spoofDpiBody: "OffVeil uses SpoofDPI for access routing in current versions. License and attribution details will be listed here.",

            .protectionActive: "Protection Active",
            .protectionInactive: "Protection Inactive",
            .clearAll: "Clear All",
            .checkUpdates: "Check updates",
            .operationFailed: "Operation failed",
            .resetFailed: "Reset failed",

            .ispDetecting: "Detecting...",
            .ispUnknown: "Unknown",
            .ispDetectionFailed: "Detection failed"
        ],
        .tr: [
            .settingsTitle: "Ayarlar",
            .aboutTitle: "Hakkinda",
            .openSourceLicensesTitle: "Acik Kaynak Lisanslari",

            .startupSection: "Baslangic",
            .launchAtLoginTitle: "Giriste Baslat",
            .launchAtLoginSubtitle: "macOS acildiginda OffVeil baslasin",
            .autoActiveTitle: "Acilista Otomatik Aktif",
            .autoActiveSubtitle: "Baslangicta korumayi otomatik ac",
            .startHiddenTitle: "Gizli Baslat",
            .startHiddenSubtitle: "Sadece menu barda acilsin",

            .languageSection: "Dil",
            .appLanguageTitle: "Uygulama Dili",
            .applyLanguageButton: "Dili Uygula",

            .infoSection: "Bilgi",
            .aboutRowTitle: "Hakkinda",
            .aboutRowSubtitle: "Surum, emek verenler ve yasal bilgiler",

            .applicationSection: "Uygulama",
            .secureTunnel: "Guvenli Tunel",
            .versionLabel: "Surum",
            .buildLabel: "Build",

            .legalSection: "Yasal",
            .openSourceRowTitle: "Acik Kaynak Lisanslari",
            .openSourceRowSubtitle: "Ucuncu taraf bilesenler ve lisanslar",

            .openSourceSection: "Acik Kaynak",
            .spoofDpiBody: "OffVeil mevcut surumlerde erisim yonlendirmesi icin SpoofDPI kullanir. Lisans ve atif detaylari burada listelenecek.",

            .protectionActive: "Koruma Aktif",
            .protectionInactive: "Koruma Pasif",
            .clearAll: "Temizle",
            .checkUpdates: "Guncellemeleri kontrol et",
            .operationFailed: "Islem basarisiz",
            .resetFailed: "Sifirlama basarisiz",

            .ispDetecting: "Algilaniyor...",
            .ispUnknown: "Bilinmiyor",
            .ispDetectionFailed: "Algilama basarisiz"
        ]
    ]
}
