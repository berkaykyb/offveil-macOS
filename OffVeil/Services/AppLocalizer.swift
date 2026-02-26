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

    case protectionActive
    case protectionInactive
    case connectionSecured
    case tapToEnable
    case reset
    case resetConfirm
    case checkUpdates
    case operationFailed
    case resetFailed

    case errorNoNetwork
    case errorPortInUse
    case errorEngineStart
    case errorProxyFailed
    case errorTimeout
    case errorDeactivateRetry
    case errorGeneric

    case themeSection
    case themeEnergy
    case themeClassic

    case updateAvailable
    case updateDownloading
    case updateInstalling
    case upToDate

    case notifProtectionOn
    case notifProtectionOff
    case notifProtectionOnBody
    case notifProtectionOffBody
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


            .protectionActive: "Protection Active",
            .protectionInactive: "Protection Inactive",
            .connectionSecured: "Your connection is secured",
            .tapToEnable: "Click to enable protection",
            .reset: "Reset",
            .resetConfirm: "Are you sure?",
            .checkUpdates: "Check for Updates",
            .operationFailed: "Operation failed",
            .resetFailed: "Reset failed",

            .errorNoNetwork: "No internet connection found. Check your network.",
            .errorPortInUse: "Another app is using the required port. Close it and try again.",
            .errorEngineStart: "Could not start the protection engine. Try Reset.",
            .errorProxyFailed: "Could not configure system proxy. Try Reset.",
            .errorTimeout: "The operation timed out. Try again.",
            .errorDeactivateRetry: "Could not fully deactivate. Try again or use Reset.",
            .errorGeneric: "Something went wrong. Try again or use Reset.",

            .themeSection: "Theme",
            .themeEnergy: "Energy",
            .themeClassic: "Classic",

            .updateAvailable: "Update Available",
            .updateDownloading: "Downloading...",
            .updateInstalling: "Installing...",
            .upToDate: "Up to date",

            .notifProtectionOn: "Protection Enabled",
            .notifProtectionOff: "Protection Disabled",
            .notifProtectionOnBody: "Your connection is now secured.",
            .notifProtectionOffBody: "Protection has been turned off."
        ],
        .tr: [
            .settingsTitle: "Ayarlar",
            .aboutTitle: "Hakkında",
            .openSourceLicensesTitle: "Açık Kaynak Lisansları",

            .startupSection: "Başlangıç",
            .launchAtLoginTitle: "Girişte Başlat",
            .launchAtLoginSubtitle: "macOS açıldığında OffVeil başlasın",
            .autoActiveTitle: "Açılışta Otomatik Aktif",
            .autoActiveSubtitle: "Başlangıçta korumayı otomatik aç",
            .startHiddenTitle: "Gizli Başlat",
            .startHiddenSubtitle: "Sadece menü barda açılsın",

            .languageSection: "Dil",
            .appLanguageTitle: "Uygulama Dili",
            .applyLanguageButton: "Dili Uygula",

            .infoSection: "Bilgi",
            .aboutRowTitle: "Hakkında",
            .aboutRowSubtitle: "Sürüm, emek verenler ve yasal bilgiler",

            .applicationSection: "Uygulama",
            .secureTunnel: "Güvenli Tünel",
            .versionLabel: "Sürüm",
            .buildLabel: "Build",

            .legalSection: "Yasal",
            .openSourceRowTitle: "Açık Kaynak Lisansları",
            .openSourceRowSubtitle: "Üçüncü taraf bileşenler ve lisanslar",

            .openSourceSection: "Açık Kaynak",


            .protectionActive: "Koruma Aktif",
            .protectionInactive: "Koruma Pasif",
            .connectionSecured: "Bağlantınız güvende",
            .tapToEnable: "Korumayı etkinleştirmek için tıklayın",
            .reset: "Sıfırla",
            .resetConfirm: "Emin misiniz?",
            .checkUpdates: "Güncellemeleri kontrol et",
            .operationFailed: "İşlem başarısız",
            .resetFailed: "Sıfırlama başarısız",

            .errorNoNetwork: "İnternet bağlantısı bulunamadı. Ağınızı kontrol edin.",
            .errorPortInUse: "Başka bir uygulama gerekli portu kullanıyor. Kapatıp tekrar deneyin.",
            .errorEngineStart: "Koruma motoru başlatılamadı. Sıfırla'yı deneyin.",
            .errorProxyFailed: "Sistem proxy ayarları yapılamadı. Sıfırla'yı deneyin.",
            .errorTimeout: "İşlem zaman aşımına uğradı. Tekrar deneyin.",
            .errorDeactivateRetry: "Tam olarak kapatılamadı. Tekrar deneyin veya Sıfırla'yı kullanın.",
            .errorGeneric: "Bir sorun oluştu. Tekrar deneyin veya Sıfırla'yı kullanın.",

            .themeSection: "Tema",
            .themeEnergy: "Enerji",
            .themeClassic: "Klasik",

            .updateAvailable: "Güncelleme Mevcut",
            .updateDownloading: "İndiriliyor...",
            .updateInstalling: "Kuruluyor...",
            .upToDate: "Güncel",

            .notifProtectionOn: "Koruma Etkinleştirildi",
            .notifProtectionOff: "Koruma Devre Dışı",
            .notifProtectionOnBody: "Bağlantınız artık güvende.",
            .notifProtectionOffBody: "Koruma kapatıldı."
        ]
    ]
}
