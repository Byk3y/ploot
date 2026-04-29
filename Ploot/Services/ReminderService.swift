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
    private init() {
        // Drop any trial-ending push left over from a previous install
        // — that reminder has been removed from the product.
        center.removePendingNotificationRequests(withIdentifiers: ["ploot.trial.ending"])
    }

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
    /// at 00:00 is rude. Then subtract the user's default lead time
    /// (Settings → Reminders → Default lead time) so a 5pm task with a
    /// 15-minute lead fires at 4:45pm. Finally, defer past quiet hours
    /// when the resulting fire date falls inside the user's quiet
    /// window — better to ping after they're awake than not at all.
    private func reminderFireDate(for task: PlootTask) -> Date? {
        guard let due = task.dueDate else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: due)
        let minute = cal.component(.minute, from: due)
        let normalized: Date
        if hour == 0 && minute == 0 {
            normalized = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
        } else {
            normalized = due
        }
        let lead = UserPrefs.defaultLeadMinutes
        let withLead = lead > 0
            ? normalized.addingTimeInterval(-Double(lead) * 60)
            : normalized
        return UserPrefs.deferPastQuietHours(withLead, calendar: cal)
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
