import Foundation
import SwiftData

/// One-shot sweep that pushes yesterday's (and earlier) incomplete-but-
/// dated tasks forward to today. Only runs when the user has opted in
/// via `Settings → Today → Auto-roll incomplete to tomorrow`.
///
/// "Roll forward" semantics: every overdue, undone, live task with a
/// `dueDate < startOfToday` gets restamped to today, preserving its
/// original time-of-day. We don't touch tasks the user explicitly left
/// dateless — those weren't on the schedule to begin with.
///
/// Called from `PlootApp` when scenePhase becomes `.active` so the
/// sweep happens at most once per app foregrounding (not once per
/// minute or per view appear). Idempotent on the same day — if every
/// overdue task has already been rolled, the next call is a no-op.
@MainActor
enum AutoRollService {
    /// Track the last sweep date so we don't roll twice in one day.
    /// Stored as a "yyyy-MM-dd" string via `UserPrefs.dateKey()` — same
    /// pattern as the streak bookkeeping.
    private static let lastSweepKey = "ploot.autoRoll.lastSweep"

    static func sweepIfEnabled(context: ModelContext) {
        guard UserPrefs.autoRollIncomplete else { return }
        let today = UserPrefs.dateKey()
        let last = UserDefaults.standard.string(forKey: lastSweepKey) ?? ""
        if last == today { return }

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)

        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate<PlootTask> { t in
                t.done == false && t.deletedAt == nil
            }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []

        for task in candidates {
            guard let due = task.dueDate, due < startOfToday else { continue }
            let h = cal.component(.hour, from: due)
            let m = cal.component(.minute, from: due)
            let rolled = cal.date(bySettingHour: h, minute: m, second: 0, of: startOfToday) ?? startOfToday
            task.dueDate = rolled
            task.section = .today
            task.touch()
            ReminderService.shared.schedule(for: task)
            SyncService.shared.push(task: task)
        }
        try? context.save()
        UserDefaults.standard.set(today, forKey: lastSweepKey)
    }
}
