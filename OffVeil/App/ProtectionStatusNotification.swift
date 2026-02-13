import Foundation

extension Notification.Name {
    static let offveilProtectionStatusChanged = Notification.Name("offveil.protection.status.changed")
}

enum OffVeilNotificationUserInfoKey {
    static let isActive = "isActive"
}
