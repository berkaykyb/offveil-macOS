//
//  NotificationService.swift
//  OffVeil
//
//  Sends macOS system notifications when protection state changes.
//

import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var authorized = false
    private var configured = false

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Must be called after app finishes launching (bundle identifier must be available).
    func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }

        if !configured {
            UNUserNotificationCenter.current().delegate = self
            configured = true
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    // MARK: - Send Notification

    func sendProtectionNotification(isActive: Bool) {
        guard authorized else { return }

        let settings = SettingsManager.shared
        let lang = settings.appLanguage

        let title = isActive
            ? AppLocalizer.text(.notifProtectionOn, language: lang)
            : AppLocalizer.text(.notifProtectionOff, language: lang)
        let body = isActive
            ? AppLocalizer.text(.notifProtectionOnBody, language: lang)
            : AppLocalizer.text(.notifProtectionOffBody, language: lang)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "offveil.protection.\(isActive ? "on" : "off")",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notification even when app is in foreground (menu bar app is always "foreground")
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
