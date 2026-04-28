import Foundation

/// Client-side cache of the onboarding answers + every behavior toggle
/// the user can change in Settings. Surfaces a single read API so
/// services outside Views (ReminderService, AutoRoll) can pull values
/// synchronously without @AppStorage observation.
///
/// New keys added in Phase 4 (Settings redesign): all default to the
/// "expected" behavior so an existing user upgrades into the same app
/// they had yesterday. New users still go through onboarding for the
/// onboarding-bound keys (dailyGoal, checkinHour/Minute, trackStreak,
/// reminderStyle).
enum UserPrefs {
    enum Key {
        // Onboarding-bound
        static let dailyGoal = "ploot.dailyGoal"
        static let checkinHour = "ploot.checkinHour"
        static let checkinMinute = "ploot.checkinMinute"
        static let trackStreak = "ploot.trackStreak"
        static let reminderStyle = "ploot.reminderStyle"

        // Settings — Daily routine
        static let streakRule = "ploot.streakRule" // "anyTask" | "goalHit"

        // Settings — Reminders
        static let autoRemindNew = "ploot.autoRemindNew" // Bool
        static let defaultLeadMinutes = "ploot.defaultLeadMinutes" // Int (0=at due, 5,15,30,60,120)
        static let quietHoursEnabled = "ploot.quietHoursEnabled" // Bool
        static let quietHoursStart = "ploot.quietHoursStart" // Int hour 0-23
        static let quietHoursEnd = "ploot.quietHoursEnd" // Int hour 0-23
        static let hapticsEnabled = "ploot.hapticsEnabled" // Bool

        // Settings — Quick add
        static let defaultProjectId = "ploot.defaultProjectId" // String? (nil/empty = inbox)
        static let defaultSchedule = "ploot.defaultSchedule" // "noDate" | "today"

        // Settings — AI breakdown
        static let useAIBreakdown = "ploot.useAIBreakdown" // Bool
        static let defaultTimelineMode = "ploot.defaultTimelineMode" // "drip" | "thisWeekend" | "thisWeek" | "nextTwoWeeks"
        static let breakdownQuestions = "ploot.breakdownQuestions" // Int 0-5

        // Settings — Today
        static let showOverdueSeparately = "ploot.showOverdueSeparately" // Bool
        static let autoRollIncomplete = "ploot.autoRollIncomplete" // Bool
        static let sortOrder = "ploot.sortOrder" // "dueTime" | "created" | "priority"

        // Settings — Cleanup
        static let autoArchiveDays = "ploot.autoArchiveDays" // Int (0=never, 7, 30)
        static let confirmBeforeDelete = "ploot.confirmBeforeDelete" // Bool

        // Settings — Appearance
        static let weekStartsOn = "ploot.weekStartsOn" // Int 1=Sun, 2=Mon
    }

    // MARK: - Read

    private static let defaults = UserDefaults.standard

    private static func bool(_ key: String, default fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.bool(forKey: key)
    }

    private static func int(_ key: String, default fallback: Int) -> Int {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.integer(forKey: key)
    }

    private static func string(_ key: String, default fallback: String) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    static var dailyGoal: Int {
        let v = defaults.integer(forKey: Key.dailyGoal)
        return v == 0 ? 5 : v
    }

    static var checkinHour: Int { int(Key.checkinHour, default: 8) }
    static var checkinMinute: Int { int(Key.checkinMinute, default: 47) }
    static var trackStreak: Bool { bool(Key.trackStreak, default: true) }
    static var reminderStyle: String { string(Key.reminderStyle, default: "gentle") }

    // Streak rule — what counts a day as "secured"?
    enum StreakRule: String, CaseIterable {
        case anyTask
        case goalHit
        var label: String {
            switch self {
            case .anyTask: return "Any task done"
            case .goalHit: return "Goal hit"
            }
        }
    }
    static var streakRule: StreakRule {
        // Default to .anyTask — on-brand "calm, not punishing": one
        // completion is enough to keep the streak alive. Users who want
        // the stricter "complete the daily goal" bar can switch in
        // Settings → Daily routine → "Streak counts when…".
        StreakRule(rawValue: string(Key.streakRule, default: StreakRule.anyTask.rawValue)) ?? .anyTask
    }

    // Reminders
    // Default OFF: most users add tasks to capture, not to be buzzed.
    // Quality apps (Things, Reminders, TickTick) all default this off
    // so the per-task "Remind me" toggle in QuickAdd is the explicit
    // opt-in. Avoids notification fatigue + per-task surprise pings.
    static var autoRemindNew: Bool { bool(Key.autoRemindNew, default: false) }
    static var defaultLeadMinutes: Int { int(Key.defaultLeadMinutes, default: 0) }
    static var quietHoursEnabled: Bool { bool(Key.quietHoursEnabled, default: false) }
    static var quietHoursStart: Int { int(Key.quietHoursStart, default: 22) }
    static var quietHoursEnd: Int { int(Key.quietHoursEnd, default: 7) }
    static var hapticsEnabled: Bool { bool(Key.hapticsEnabled, default: true) }

    // Quick add
    static var defaultProjectId: String? {
        let v = defaults.string(forKey: Key.defaultProjectId)
        return (v?.isEmpty ?? true) ? nil : v
    }

    enum DefaultSchedule: String, CaseIterable {
        case noDate
        case today
        var label: String {
            switch self {
            case .noDate: return "No date"
            case .today: return "Today"
            }
        }
    }
    // Default `.noDate`: capture tasks should land dateless, not be
    // pre-committed to today. Pre-committing pollutes Today with
    // no-intent noise, which breaks the streak rule's contract that
    // Today reflects intention.
    static var defaultSchedule: DefaultSchedule {
        DefaultSchedule(rawValue: string(Key.defaultSchedule, default: DefaultSchedule.noDate.rawValue)) ?? .noDate
    }

    // AI breakdown
    static var useAIBreakdown: Bool { bool(Key.useAIBreakdown, default: true) }
    static var defaultTimelineMode: String { string(Key.defaultTimelineMode, default: "drip") }
    static var breakdownQuestions: Int { int(Key.breakdownQuestions, default: 3) }

    // Today
    static var showOverdueSeparately: Bool { bool(Key.showOverdueSeparately, default: true) }
    static var autoRollIncomplete: Bool { bool(Key.autoRollIncomplete, default: false) }

    enum SortOrder: String, CaseIterable {
        case dueTime
        case created
        case priority
        var label: String {
            switch self {
            case .dueTime: return "Due time"
            case .created: return "Created"
            case .priority: return "Priority"
            }
        }
    }
    static var sortOrder: SortOrder {
        SortOrder(rawValue: string(Key.sortOrder, default: SortOrder.dueTime.rawValue)) ?? .dueTime
    }

    // Cleanup
    static var autoArchiveDays: Int { int(Key.autoArchiveDays, default: 30) }
    static var confirmBeforeDelete: Bool { bool(Key.confirmBeforeDelete, default: true) }

    // Appearance
    // Default = system locale's `firstWeekday`. Hardcoding Monday or
    // Sunday silently overrides what the user already configured in
    // iOS Settings → Calendar — bad form. Users who want a different
    // start can flip it in Settings here, which then takes precedence.
    static var weekStartsOn: Int {
        guard defaults.object(forKey: Key.weekStartsOn) != nil else {
            return Calendar.current.firstWeekday
        }
        return defaults.integer(forKey: Key.weekStartsOn)
    }

    // MARK: - Write

    static func apply(from answers: OnboardingAnswers) {
        defaults.set(answers.dailyGoal, forKey: Key.dailyGoal)

        let comps = Calendar.current.dateComponents([.hour, .minute], from: answers.checkinTime)
        defaults.set(comps.hour ?? 8, forKey: Key.checkinHour)
        defaults.set(comps.minute ?? 47, forKey: Key.checkinMinute)

        defaults.set(answers.trackStreak, forKey: Key.trackStreak)
        defaults.set(answers.reminderStyle.rawValue, forKey: Key.reminderStyle)
    }

    /// Hydrate from a server-side profile snapshot. Called on a returning
    /// user sign-in. Only touches keys the snapshot has values for.
    static func apply(from snapshot: SyncService.OnboardingProfileSnapshot) {
        if let goal = snapshot.daily_goal {
            defaults.set(goal, forKey: Key.dailyGoal)
        }
        if let timeString = snapshot.checkin_time {
            let parts = timeString.split(separator: ":")
            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                defaults.set(h, forKey: Key.checkinHour)
                defaults.set(m, forKey: Key.checkinMinute)
            }
        }
        if let track = snapshot.track_streak {
            defaults.set(track, forKey: Key.trackStreak)
        }
        if let style = snapshot.reminder_style {
            defaults.set(style, forKey: Key.reminderStyle)
        }
    }

    /// Reset on sign-out so the next user of this device starts clean.
    static func wipe() {
        let allKeys = [
            Key.dailyGoal, Key.checkinHour, Key.checkinMinute,
            Key.trackStreak, Key.reminderStyle,
            Key.streakRule,
            // Legacy streak bookkeeping (now derived from completedAt) —
            // wipe stale AppStorage so old installs don't carry orphans.
            "ploot.streak.count", "ploot.streak.lastDate",
            Key.autoRemindNew, Key.defaultLeadMinutes,
            Key.quietHoursEnabled, Key.quietHoursStart, Key.quietHoursEnd,
            Key.hapticsEnabled,
            Key.defaultProjectId, Key.defaultSchedule,
            Key.useAIBreakdown, Key.defaultTimelineMode, Key.breakdownQuestions,
            Key.showOverdueSeparately, Key.autoRollIncomplete, Key.sortOrder,
            Key.autoArchiveDays, Key.confirmBeforeDelete,
            Key.weekStartsOn
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Helpers

    /// Today in local time as "yyyy-MM-dd". Stable string for streak
    /// bookkeeping across day boundaries without timezone drift.
    static func dateKey(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    /// Returns true if `date` falls within the user's quiet hours window.
    /// Window can wrap midnight (e.g. 22 → 7 means "10pm to 7am").
    static func isInQuietHours(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        let start = quietHoursStart
        let end = quietHoursEnd
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        } else {
            return hour >= start || hour < end
        }
    }

    /// Pushes `date` past the quiet-hours window. If `date` falls in
    /// quiet hours, returns the next occurrence of `quietHoursEnd`. Used
    /// to defer reminder firing until the user is awake.
    static func deferPastQuietHours(_ date: Date, calendar: Calendar = .current) -> Date {
        guard isInQuietHours(date, calendar: calendar) else { return date }
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let hour = comps.hour ?? 0
        // If we're past quietHoursStart but before midnight, push to
        // tomorrow's quietHoursEnd. Otherwise (we're in 0…end), today's
        // quietHoursEnd is enough.
        if quietHoursStart > quietHoursEnd, hour >= quietHoursStart {
            comps.day = (comps.day ?? 0) + 1
        }
        comps.hour = quietHoursEnd
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }
}
