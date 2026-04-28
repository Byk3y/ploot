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
        let filtered = tasks.filter { $0.isLive && derivedSection(for: $0, asOf: now) == section }
        return sorted(filtered)
    }

    /// Apply the user's `Settings → Today → Sort by` preference. Used
    /// for both the bucketed Today list and any other "list of tasks"
    /// surface.
    /// - Due time: ascending dueDate, dateless rows fall to the end.
    /// - Created: newest first (matches the natural inbox flow).
    /// - Priority: high → normal → low; ties resolve by createdAt desc.
    static func sorted(_ tasks: [PlootTask]) -> [PlootTask] {
        switch UserPrefs.sortOrder {
        case .dueTime:
            return tasks.sorted { lhs, rhs in
                let l = lhs.dueDate ?? .distantFuture
                let r = rhs.dueDate ?? .distantFuture
                if l != r { return l < r }
                return lhs.createdAt > rhs.createdAt
            }
        case .created:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .priority:
            return tasks.sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority.sortRank < rhs.priority.sortRank
                }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    /// Live, done tasks. Honors `Settings → Cleanup → Auto-archive done`
    /// by hiding (not deleting) rows whose `completedAt` is older than
    /// the configured cutoff. `autoArchiveDays == 0` means "never
    /// archive" — every done row stays visible.
    static func doneTasks(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlootTask] {
        let archiveDays = UserPrefs.autoArchiveDays
        let cutoff: Date? = archiveDays > 0
            ? calendar.date(byAdding: .day, value: -archiveDays, to: now)
            : nil
        return tasks.filter { task in
            guard task.isLive, task.done else { return false }
            if let cutoff, let completedAt = task.completedAt, completedAt < cutoff {
                return false
            }
            return true
        }
    }

    /// Count of tasks the user has completed today — measured by
    /// `completedAt` within the local calendar day, not by current
    /// section. Used by TodayScreen to show progress toward the user's
    /// daily goal.
    static func completedToday(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return tasks.filter { task in
            guard task.isLive, task.done, let c = task.completedAt else { return false }
            return c >= start && c < end
        }.count
    }

    /// Drop tombstoned rows. Use this anywhere the UI lists tasks.
    static func live(_ tasks: [PlootTask]) -> [PlootTask] {
        tasks.filter { $0.isLive }
    }

    // MARK: - Day filtering (for Calendar)

    /// All live tasks scheduled on a given calendar day, sorted by time-
    /// of-day. Includes done tasks so the calendar can show what was
    /// completed; the row's strikethrough handles the visual.
    static func tasks(
        on day: Date,
        from tasks: [PlootTask],
        calendar: Calendar = .current
    ) -> [PlootTask] {
        tasks
            .filter { task in
                guard task.isLive, let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    /// Count of live, undone tasks on a given day. Drives the density
    /// dots on the calendar grid — done tasks intentionally drop out so
    /// "everything crushed" days look light, not crowded.
    static func openTaskCount(
        on day: Date,
        from tasks: [PlootTask],
        calendar: Calendar = .current
    ) -> Int {
        tasks.filter { task in
            guard task.isLive, !task.done, let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }.count
    }

    // MARK: - Lateness

    /// Past its due date *right now* (regardless of whether it crossed a
    /// day boundary). Same-day past-time tasks count too — a task due
    /// "today 3 pm" at 5 pm is late. Done tasks never count as late.
    static func isLate(_ task: PlootTask, asOf now: Date = Date()) -> Bool {
        guard !task.done, let due = task.dueDate else { return false }
        return due < now
    }

    /// Relative-time copy for tasks that crossed a day boundary
    /// ("yesterday", "2d late", "3w late"). Returns nil for tasks that
    /// are only same-day late, or not late, or have no due date —
    /// same-day late just gets the regular display label with a warm
    /// tint applied at the row level.
    static func lateLabel(
        for task: PlootTask,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard !task.done, let due = task.dueDate else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        guard due < startOfToday else { return nil }

        let dueDay = calendar.startOfDay(for: due)
        let daysLate = calendar.dateComponents([.day], from: dueDay, to: startOfToday).day ?? 0
        switch daysLate {
        case 1:
            return "yesterday"
        case 2...6:
            return "\(daysLate)d late"
        case 7...29:
            return "\(daysLate / 7)w late"
        default:
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = "MMM d"
            return fmt.string(from: due)
        }
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

    /// Consecutive-day completion streak ending today. A day "counts" once
    /// it accumulates at least `threshold(rule, dailyGoal)` completions:
    ///   - `.anyTask`: any one completion is enough.
    ///   - `.goalHit`: needs `dailyGoal` completions to secure the day.
    ///
    /// Today stays alive even before the user secures it — if yesterday
    /// counted and today hasn't yet, we anchor on yesterday and treat
    /// today as "at risk" rather than broken.
    ///
    /// This is the *single source of truth* for streak math. TodayScreen
    /// and DoneScreen both compute through here so they can never drift.
    static func streak(
        from tasks: [PlootTask],
        rule: UserPrefs.StreakRule = .anyTask,
        dailyGoal: Int = 1,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let securedDays = securedDays(from: tasks, rule: rule, dailyGoal: dailyGoal, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let anchor: Date
        if securedDays.contains(today) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  securedDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }
        var count = 0
        var day = anchor
        while securedDays.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Longest historical consecutive-day completion run.
    static func bestStreak(
        from tasks: [PlootTask],
        rule: UserPrefs.StreakRule = .anyTask,
        dailyGoal: Int = 1,
        calendar: Calendar = .current
    ) -> Int {
        let days = securedDays(from: tasks, rule: rule, dailyGoal: dailyGoal, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for i in 1..<days.count {
            let prev = days[i - 1]
            let curr = days[i]
            if let next = calendar.date(byAdding: .day, value: 1, to: prev), next == curr {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    /// Set of local-day starts that satisfy the streak rule. For `.anyTask`,
    /// any day with at least one completion. For `.goalHit`, only days
    /// where completion count met `dailyGoal`.
    private static func securedDays(
        from tasks: [PlootTask],
        rule: UserPrefs.StreakRule,
        dailyGoal: Int,
        calendar: Calendar
    ) -> Set<Date> {
        let dayCounts = tasks
            .filter { $0.isLive }
            .compactMap { $0.completedAt }
            .map { calendar.startOfDay(for: $0) }
            .reduce(into: [Date: Int]()) { acc, day in acc[day, default: 0] += 1 }

        let threshold: Int = {
            switch rule {
            case .anyTask: return 1
            case .goalHit: return max(1, dailyGoal)
            }
        }()
        return Set(dayCounts.filter { $0.value >= threshold }.keys)
    }

    enum StreakState { case onFire, atRisk, cold }

    /// Folds the streak status:
    /// - `.cold` when the user has no active streak.
    /// - `.atRisk` when there is a streak but today isn't secured yet.
    /// - `.onFire` when there is a streak and today is already secured.
    static func streakState(
        from tasks: [PlootTask],
        rule: UserPrefs.StreakRule = .anyTask,
        dailyGoal: Int = 1,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakState {
        let current = streak(from: tasks, rule: rule, dailyGoal: dailyGoal, asOf: now, calendar: calendar)
        guard current > 0 else { return .cold }
        let today = calendar.startOfDay(for: now)
        let securedToday = securedDays(from: tasks, rule: rule, dailyGoal: dailyGoal, calendar: calendar)
            .contains(today)
        return securedToday ? .onFire : .atRisk
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
                guard task.isLive, let completedAt = task.completedAt else { return false }
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

    /// Sum of the seven daily counts in `weeklyCounts`. Use for the Done
    /// screen's "<n> this week" subtitle.
    static func weekTotalDone(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        weeklyCounts(from: tasks, asOf: now, calendar: calendar)
            .map(\.count)
            .reduce(0, +)
    }

    /// Seven-day bar row for the *current calendar week* (not the
    /// trailing 7 days). Honors `Settings → Appearance → Week starts on`
    /// via `Calendar.ploot.firstWeekday`, so the row reads M…S for
    /// Monday-start users and S…S for Sunday-start users.
    static func currentWeekCounts(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar baseCalendar: Calendar = .ploot
    ) -> [DayBucket] {
        let calendar = baseCalendar

        let labelFmt = DateFormatter()
        labelFmt.locale = Locale(identifier: "en_US")
        labelFmt.dateFormat = "EEEEE"

        // Walk back from `now` until we hit the configured firstWeekday.
        var weekStart = calendar.startOfDay(for: now)
        while calendar.component(.weekday, from: weekStart) != calendar.firstWeekday {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: weekStart) else { break }
            weekStart = prev
        }

        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let count = tasks.filter { task in
                guard task.isLive, let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            return DayBucket(
                date: day,
                label: labelFmt.string(from: day),
                count: count,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    static func weekTotalDoneCalendarWeek(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        currentWeekCounts(from: tasks, asOf: now, calendar: calendar)
            .map(\.count)
            .reduce(0, +)
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

    // MARK: - Today progress

    /// Tasks whose effective day is today, *regardless of completion*. This
    /// is the right denominator for "X of Y today" — done tasks must stay
    /// counted so the ratio actually reflects progress.
    static func todayTaskSet(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlootTask] {
        tasks.filter { task in
            guard task.isLive else { return false }
            if let due = task.dueDate {
                return calendar.isDate(due, inSameDayAs: now)
            }
            // Dateless task parked in the Today bucket counts too.
            return task.section == .today
        }
    }

    /// (done, total) for the today-due set. Replaces the old subtitle math
    /// which excluded done tasks from the denominator and always reported
    /// `done = 0`.
    static func todayProgress(
        from tasks: [PlootTask],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> (done: Int, total: Int) {
        let set = todayTaskSet(from: tasks, asOf: now, calendar: calendar)
        return (done: set.filter(\.done).count, total: set.count)
    }

    // MARK: - Today voice line

    /// Time-of-day greeting (no name appended). Empty when in late-night
    /// hours so callers can fall through to a different copy register.
    static func timeOfDayGreeting(asOf now: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default:      return "Late one"
        }
    }

    /// Single-line motivational header for the Today screen. Voice-driven,
    /// not a stat — the progress strip carries the numbers. Falls back to
    /// the original empty-list zinger when the user has nothing scheduled.
    static func todayVoiceLine(
        from tasks: [PlootTask],
        displayName: String,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let progress = todayProgress(from: tasks, asOf: now, calendar: calendar)
        let greeting = timeOfDayGreeting(asOf: now, calendar: calendar)
        let firstName = displayName
            .split(separator: " ")
            .first
            .map(String.init) ?? displayName
        let useName = !firstName.isEmpty
            && firstName.lowercased() != "you"
            && firstName != "?"
        let prefix = useName ? "\(greeting), \(firstName)." : "\(greeting)."

        if progress.total == 0 {
            return "Nothing on the list. Suspicious."
        }
        let remaining = progress.total - progress.done
        switch remaining {
        case 0:
            return "All clear. Take a victory lap."
        case 1:
            return "\(prefix) 1 to go."
        default:
            // At/over halfway → warmer copy. Below halfway → keep it factual.
            if progress.done * 2 >= progress.total && progress.done > 0 {
                return "\(prefix) Halfway there."
            }
            return "\(prefix) \(remaining) to go."
        }
    }
}
