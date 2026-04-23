import Foundation
import UserNotifications

/// Local-notification scheduling for task reminders. Everything is
/// client-side — no push infrastructure, no APNs certs. `schedule(for:)`
/// is idempotent: it cancels any existing request for the task's UUID
/// first, then schedules a new one if the task currently wants a
/// reminder in the future.
@MainActor
final class ReminderService {
    static let shared = ReminderService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Returns true once the user has allowed (or provisionally allowed)
    /// notifications. The system prompt only appears on the first call
    /// while status is `.notDetermined` — subsequent calls are silent.
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule / cancel

    /// Cancel any existing reminder for this task, then schedule a new one
    /// if the task wants one, isn't done, and the fire date is in the
    /// future. Safe to call on every mutation.
    func schedule(for task: PlootTask) {
        cancel(for: task)
        guard task.remindMe == true, !task.done else { return }
        guard let fireDate = reminderFireDate(for: task), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = reminderBody(for: task, fireDate: fireDate)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancel(for task: PlootTask) {
        cancel(taskId: task.id)
    }

    func cancel(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }

    // MARK: - Daily check-in (driven by UserPrefs.checkinHour/Minute)

    private static let checkinID = "ploot.checkin"

    /// Schedule the recurring daily ping at the user's check-in time.
    /// Copy is modulated by `UserPrefs.reminderStyle`. Safe to call
    /// repeatedly — existing request is cancelled first.
    ///
    /// Skipped silently when `reminderStyle == "none"`.
    func scheduleDailyCheckin() {
        cancelDailyCheckin()
        let style = UserPrefs.reminderStyle
        guard style != "none" else { return }

        let content = UNMutableNotificationContent()
        content.title = checkinTitle(style: style)
        content.body = checkinBody(style: style)
        content.sound = .default

        var components = DateComponents()
        components.hour = UserPrefs.checkinHour
        components.minute = UserPrefs.checkinMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.checkinID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelDailyCheckin() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.checkinID])
    }

    // MARK: - Trial-ending reinforcement

    private static let trialEndingID = "ploot.trial.ending"

    /// Schedule a one-shot push 2 hours before the current period ends.
    /// Called by SubscriptionManager whenever entitlements refresh.
    ///
    /// No-op when `endDate` is nil, in the past, or when we're not in
    /// a free trial (paid subscribers don't need "you're about to be
    /// charged" anxiety — the native App Store already handles that).
    func scheduleTrialEndingReminder(at endDate: Date?, isInTrial: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialEndingID])
        guard isInTrial, let endDate, endDate > Date() else { return }

        let fireDate = endDate.addingTimeInterval(-60 * 60 * 2)  // T-2h
        guard fireDate > Date() else { return }  // too close to schedule

        let content = UNMutableNotificationContent()
        content.title = "Trial ends in 2 hours"
        content.body = "Keep your plan, your projects, and your streak 🔥 — tap to continue."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.trialEndingID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func checkinTitle(style: String) -> String {
        switch style {
        case "firm": return "Today's goal — \(UserPrefs.dailyGoal) crushes"
        case "gentle": return "🧡 Ploot check-in"
        default: return "🧡 Ploot"
        }
    }

    private func checkinBody(style: String) -> String {
        switch style {
        case "firm": return "You picked the plan. Let's go."
        case "gentle": return "What's on the list today?"
        default: return "A soft nudge from your list."
        }
    }

    // MARK: - Fire-date + body derivation

    /// Where the notification actually fires. If the task's dueDate is
    /// midnight-aligned (user picked a day with no time slot), shift to
    /// 9 AM local that day — notifying someone about "water the plant"
    /// at 00:00 is rude. Otherwise fire at the exact dueDate.
    private func reminderFireDate(for task: PlootTask) -> Date? {
        guard let due = task.dueDate else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: due)
        let minute = cal.component(.minute, from: due)
        if hour == 0 && minute == 0 {
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: due)
        }
        return due
    }

    /// Brand-voice notification body. Prefers the user's own note when
    /// present (it's their voice, and the most useful context at the
    /// fire moment), otherwise falls back to the formatted due label.
    private func reminderBody(for task: PlootTask, fireDate: Date) -> String {
        if let note = task.note, !note.isEmpty {
            return note
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        let time = fmt.string(from: fireDate)
        return "due at \(time). no pressure."
    }
}
