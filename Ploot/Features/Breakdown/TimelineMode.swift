import Foundation

/// User-selected pacing window for an AI-broken-down project. Default is
/// `.drip` — first task today, rest dateless, surfaced one at a time as
/// the user finishes each one. The other modes spread tasks across an
/// explicit window so the calendar reflects the user's intent.
enum TimelineMode: Equatable, Hashable {
    case drip
    case thisWeekend
    case thisWeek
    case nextTwoWeeks
    case picked(Date)

    var label: String {
        switch self {
        case .drip:         return "drip as you go"
        case .thisWeekend:  return "this weekend"
        case .thisWeek:     return "this week"
        case .nextTwoWeeks: return "next 2 weeks"
        case .picked:       return "pick a date"
        }
    }

    /// Days the tasks should be distributed across. Empty for `.drip`
    /// (caller short-circuits). All returned days are at startOfDay so
    /// the scheduler can stamp times onto them cleanly.
    func days(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        switch self {
        case .drip:
            return []

        case .thisWeekend:
            return Self.upcomingWeekendDays(now: now, calendar: calendar)

        case .thisWeek:
            return Self.remainingWeekDays(now: now, calendar: calendar)

        case .nextTwoWeeks:
            return Self.daysFromTomorrow(count: 14, now: now, calendar: calendar)

        case .picked(let target):
            return Self.daysBetween(start: now, end: target, calendar: calendar)
        }
    }

    // MARK: - Window math

    /// Saturday + Sunday of the upcoming weekend. If today is Sat or Sun,
    /// only the remaining days. If today is Mon–Thu, this Sat–Sun. If
    /// today is Fri, tomorrow + Sun.
    private static func upcomingWeekendDays(now: Date, calendar: Calendar) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: startOfToday) // Sun=1 ... Sat=7

        // Distance from today to upcoming Saturday (inclusive when today is Sat).
        let daysUntilSat: Int = {
            switch weekday {
            case 7: return 0  // already Saturday
            case 1: return -1 // Sunday — Saturday already gone, treat as in-weekend
            default: return 7 - weekday
            }
        }()

        var days: [Date] = []
        if daysUntilSat == -1 {
            // Today is Sunday — only Sunday remaining.
            days.append(startOfToday)
        } else {
            if let sat = calendar.date(byAdding: .day, value: daysUntilSat, to: startOfToday) {
                days.append(sat)
            }
            if let sun = calendar.date(byAdding: .day, value: daysUntilSat + 1, to: startOfToday) {
                days.append(sun)
            }
        }
        return days
    }

    /// Today + each following day through Sunday of the current calendar
    /// week (firstWeekday=Monday). If today is Sunday, this returns just
    /// today.
    private static func remainingWeekDays(now: Date, calendar: Calendar) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        // Apple weekday is fixed: Sun=1, Mon=2, ..., Sat=7 — independent
        // of `calendar.firstWeekday`. We want days remaining until the
        // upcoming Sunday inclusive, treating the week as Mon-anchored.
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysToSunday = (1 - weekday + 7) % 7 // Sun→0, Mon→6, Tue→5, ...
        let count = daysToSunday + 1
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday)
        }
    }

    private static func daysFromTomorrow(count: Int, now: Date, calendar: Calendar) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return [] }
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: tomorrow)
        }
    }

    /// Map a `UserPrefs.defaultTimelineMode` raw string back to the enum.
    /// Falls back to `.drip` for unknown values (e.g. `.picked`, which
    /// can't round-trip through a string preference cleanly).
    static func fromPref(_ raw: String) -> TimelineMode {
        switch raw {
        case "drip":         return .drip
        case "thisWeekend":  return .thisWeekend
        case "thisWeek":     return .thisWeek
        case "nextTwoWeeks": return .nextTwoWeeks
        default:             return .drip
        }
    }

    /// Stable string key for round-tripping through `UserPrefs`. Mirrors
    /// `fromPref(...)`. `.picked` collapses to `drip` because we can't
    /// store an arbitrary date in a single string pref.
    var prefKey: String {
        switch self {
        case .drip:         return "drip"
        case .thisWeekend:  return "thisWeekend"
        case .thisWeek:     return "thisWeek"
        case .nextTwoWeeks: return "nextTwoWeeks"
        case .picked:       return "drip"
        }
    }

    /// Inclusive list of days between `start` (rounded down to startOfDay)
    /// and `end` (rounded down). Returns at least one day even if the
    /// caller picked today — so a same-day deadline still gets all tasks
    /// assigned somewhere.
    private static func daysBetween(start: Date, end: Date, calendar: Calendar) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard endDay >= startDay else { return [startDay] }
        let comps = calendar.dateComponents([.day], from: startDay, to: endDay)
        let totalDays = (comps.day ?? 0) + 1
        return (0..<totalDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay)
        }
    }
}
