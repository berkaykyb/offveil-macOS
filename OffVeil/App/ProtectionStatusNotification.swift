import Foundation

extension Notification.Name {
    static let offveilProtectionStatusChanged = Notification.Name("offveil.protection.status.changed")
    static let offveilPopoverDidOpen = Notification.Name("offveil.popover.didOpen")
}

enum OffVeilNotificationUserInfoKey {
    static let isActive = "isActive"
}
