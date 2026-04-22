import Foundation

/// Derived views over a live tasks array. Every screen passes in its @Query
/// result and receives the computed value — no stored derived state.
enum TaskHelpers {

    // MARK: - Section derivation

    /// The section a task belongs in *right now*. Done takes precedence; then
    /// date-based bucketing (overdue/today/later) when `dueDate` is set;
    /// otherwise the stored `section` field is the fallback for dateless
    /// tasks.
    static func derivedSection(
        for task: PlootTask,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskSection {
        if task.done { return .done }
        guard let due = task.dueDate else {
            // Dateless task: honor the stored section, but never return .done
            // — that's what the done flag is for.
            return task.section == .done ? .today : task.section
        }
        let startOfToday = calendar.startOfDay(for: now)
        if calendar.isDate(due, inSameDayAs: now) {
            return .today
        }
        if due < startOfToday {
            return .overdue
        }
        return .later
    }

    static func tasks(
        in section: TaskSection,
        from tasks: [PlootTask],
        asOf now: Date = Date()
    ) -> [PlootTask] {
        tasks.filter { derivedSection(for: $0, asOf: now) == section }
    }

    static func doneTasks(from tasks: [PlootTask]) -> [PlootTask] {
        tasks.filter { $0.done }
    }

    // MARK: - Display labels

    /// Human-friendly "Today, 2:00 PM" / "Yesterday" / "Thu" / "Apr 29"
    /// derived from the canonical `dueDate`. Falls back to the stored string
    /// label for legacy / dateless tasks.
    static func displayLabel(
        for task: PlootTask,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let date = task.dueDate else { return task.due }

        let baseLabel: String
        if calendar.isDateInToday(date) {
            baseLabel = "Today"
        } else if calendar.isDateInYesterday(date) {
            baseLabel = "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            baseLabel = "Tomorrow"
        } else if let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day,
                  diff > 0, diff < 7 {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = "EEE"
            baseLabel = fmt.string(from: date)
        } else {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = "MMM d"
            baseLabel = fmt.string(from: date)
        }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        if hour == 0 && minute == 0 {
            return baseLabel
        }
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US")
        timeFmt.dateFormat = "h:mm a"
        return "\(baseLabel), \(timeFmt.string(from: date))"
    }

    // MARK: - Project lookup

    static func project(id: String?, from projects: [PlootProject]) -> PlootProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: - Streak

    /// Consecutive-day completion streak ending today. A day counts if at
    /// least one task has `completedAt` falling within it.
    static func streak(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let completionDays = Set(
            tasks
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
        )
        var count = 0
        var day = calendar.startOfDay(for: now)
        while completionDays.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    // MARK: - Weekly chart

    struct DayBucket: Identifiable {
        var id: Date { date }
        let date: Date
        let label: String
        let count: Int
        let isToday: Bool
    }

    /// Seven-day histogram ending today (today is the trailing bar). Labels
    /// are single-letter weekday initials. Counts are real `completedAt`
    /// rollups.
    static func weeklyCounts(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayBucket] {
        let today = calendar.startOfDay(for: now)
        let labelFmt = DateFormatter()
        labelFmt.locale = Locale(identifier: "en_US")
        labelFmt.dateFormat = "EEEEE"  // narrow (single-letter) weekday

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            return DayBucket(
                date: day,
                label: labelFmt.string(from: day),
                count: count,
                isToday: offset == 0
            )
        }
    }

    // MARK: - Avatar initials

    /// Two-letter uppercase initials for an avatar tile. "Francis Chukwuma"
    /// → "FC", "You" → "Y", "" → "?". Reads from the user's display name
    /// (stored in @AppStorage("displayName")) so Today and Settings show
    /// the same pill.
    static func avatarInitials(for displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    // MARK: - Today subtitle

    static func todaySubtitle(from tasks: [PlootTask], asOf now: Date = Date()) -> String {
        let today = self.tasks(in: .today, from: tasks, asOf: now)
        let total = today.count
        let done = today.filter { $0.done }.count
        if total == 0 {
            return "Nothing on the list. Suspicious."
        }
        return "\(done) of \(total) crushed. Keep going."
    }
}
