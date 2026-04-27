import Foundation

/// Coarse "when" buckets used by QuickAddSheet's date pill. The sheet
/// preserves arbitrary calendar dates separately via `customDate`; this
/// enum only models the quick-pick choices.
enum DueOption: String, CaseIterable, Identifiable {
    case today, tomorrow, weekend, nextweek, someday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:    return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekend:  return "Weekend"
        case .nextweek: return "Next week"
        case .someday:  return "Someday"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "sun.max"
        case .tomorrow: return "sunrise"
        case .weekend:  return "cup.and.saucer"
        case .nextweek: return "calendar.badge.clock"
        case .someday:  return "infinity"
        }
    }

    /// Resolve the user's coarse due choice into an absolute `Date`. Time
    /// slot format matches the sheet's picker strings ("8:00 AM", "2:00 PM",
    /// etc.). Someday is always nil (dateless).
    func date(
        timeSlot: String?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        let base: Date?
        switch self {
        case .today:
            base = startOfToday
        case .tomorrow:
            base = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        case .weekend:
            base = calendar.nextDate(
                after: now,
                matching: DateComponents(weekday: 7),
                matchingPolicy: .nextTime
            )
        case .nextweek:
            base = calendar.nextDate(
                after: now,
                matching: DateComponents(weekday: 2),
                matchingPolicy: .nextTime
            )
        case .someday:
            return nil
        }

        guard let base else { return nil }

        if let slot = timeSlot, let (hour, minute) = Self.parseTimeSlot(slot) {
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)
        }
        return base
    }

    private static func parseTimeSlot(_ slot: String) -> (Int, Int)? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        guard let date = fmt.date(from: slot) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        return (cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    /// Classify an existing dueDate back into the coarse picker choice. Used
    /// in edit mode to preselect the right pill. If the date is further out
    /// than "this week", returns `.someday` and the caller should preserve
    /// the absolute date separately (`customDate`).
    static func fromDate(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> DueOption {
        guard let date else { return .today }
        let startOfToday = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: date)
        let daysAhead = calendar.dateComponents([.day], from: startOfToday, to: targetDay).day ?? 0
        if daysAhead == 0 { return .today }
        if daysAhead == 1 { return .tomorrow }
        if let nextSaturday = calendar.nextDate(after: now, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime),
           calendar.isDate(date, inSameDayAs: nextSaturday) {
            return .weekend
        }
        if let nextMonday = calendar.nextDate(after: now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime),
           calendar.isDate(date, inSameDayAs: nextMonday) {
            return .nextweek
        }
        return .someday
    }
}

enum RepeatOption: String, CaseIterable, Identifiable {
    case never, daily, weekly, monthly
    var id: String { rawValue }

    static func fromStored(_ stored: String?) -> RepeatOption {
        guard let stored, let match = RepeatOption(rawValue: stored) else { return .never }
        return match
    }
}
