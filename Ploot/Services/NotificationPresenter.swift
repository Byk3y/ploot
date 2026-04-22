import Foundation
import UserNotifications

/// Lets reminders render as a banner even when the app is in the
/// foreground — without this delegate, iOS suppresses the UI because it
/// assumes the foregrounded app "already knows." Users expect to see the
/// reminder regardless of whether they happen to be looking at Ploot.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
