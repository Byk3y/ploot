import Foundation

/// Client-side cache of the onboarding answers that drive runtime
/// behavior (daily goal, check-in time, reminder style, streak).
///
/// Why mirror profile columns locally? Two reasons:
///   1. Services outside Views (ReminderService, StreakManager) can't
///      use @AppStorage directly — they need a synchronous read.
///   2. Survives offline. The check-in notification fires even when
///      the network is out.
///
/// Written in two paths:
///   * After quiz completes (Screen 22 SIWA): `apply(from: answers)`
///     alongside the Supabase profile push.
///   * After a cross-device sign-in when the profile row has values the
///     local device doesn't: `apply(from: remoteProfile)` (called from
///     `SyncService` pull path — to be wired when needed).
///
/// Keys are `ploot.*` namespaced so they don't collide with SwiftUI
/// @AppStorage usages elsewhere.
enum UserPrefs {
    // Keys — keep in one place so Views can match via @AppStorage.
    enum Key {
        static let dailyGoal = "ploot.dailyGoal"
        static let checkinHour = "ploot.checkinHour"
        static let checkinMinute = "ploot.checkinMinute"
        static let trackStreak = "ploot.trackStreak"
        static let reminderStyle = "ploot.reminderStyle"
        static let streakCount = "ploot.streak.count"
        static let streakLastDate = "ploot.streak.lastDate"
    }

    // MARK: - Read

    private static let defaults = UserDefaults.standard

    static var dailyGoal: Int {
        let v = defaults.integer(forKey: Key.dailyGoal)
        return v == 0 ? 5 : v
    }

    static var checkinHour: Int {
        // defaults.integer returns 0 when missing, which is a valid hour.
        // Check existence via object(forKey:) to tell "unset" from "midnight".
        guard defaults.object(forKey: Key.checkinHour) != nil else { return 8 }
        return defaults.integer(forKey: Key.checkinHour)
    }

    static var checkinMinute: Int {
        guard defaults.object(forKey: Key.checkinMinute) != nil else { return 47 }
        return defaults.integer(forKey: Key.checkinMinute)
    }

    static var trackStreak: Bool {
        guard defaults.object(forKey: Key.trackStreak) != nil else { return true }
        return defaults.bool(forKey: Key.trackStreak)
    }

    static var reminderStyle: String {
        defaults.string(forKey: Key.reminderStyle) ?? "gentle"
    }

    static var streakCount: Int {
        defaults.integer(forKey: Key.streakCount)
    }

    static var streakLastDate: String {
        defaults.string(forKey: Key.streakLastDate) ?? ""
    }

    // MARK: - Write

    static func setStreak(count: Int, lastDate: String) {
        defaults.set(count, forKey: Key.streakCount)
        defaults.set(lastDate, forKey: Key.streakLastDate)
    }

    static func apply(from answers: OnboardingAnswers) {
        defaults.set(answers.dailyGoal, forKey: Key.dailyGoal)

        let comps = Calendar.current.dateComponents([.hour, .minute], from: answers.checkinTime)
        defaults.set(comps.hour ?? 8, forKey: Key.checkinHour)
        defaults.set(comps.minute ?? 47, forKey: Key.checkinMinute)

        defaults.set(answers.trackStreak, forKey: Key.trackStreak)
        defaults.set(answers.reminderStyle.rawValue, forKey: Key.reminderStyle)
    }

    /// Hydrate from a server-side profile snapshot. Called on a
    /// returning-user sign-in when `onboarded_at` is set — fills in
    /// the local UserPrefs that a fresh install would otherwise leave
    /// at defaults. Only writes keys the snapshot actually has values
    /// for; missing columns preserve existing local defaults.
    static func apply(from snapshot: SyncService.OnboardingProfileSnapshot) {
        if let goal = snapshot.daily_goal {
            defaults.set(goal, forKey: Key.dailyGoal)
        }
        if let timeString = snapshot.checkin_time {
            // Postgres `time` columns render as "HH:mm:ss" (24h).
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
        for key in [
            Key.dailyGoal, Key.checkinHour, Key.checkinMinute,
            Key.trackStreak, Key.reminderStyle,
            Key.streakCount, Key.streakLastDate
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Helpers

    /// Today in local time as "yyyy-MM-dd" — stable string for streak
    /// bookkeeping so we can compare across day boundaries without
    /// timezone drift.
    static func dateKey(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
