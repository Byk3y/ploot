import Foundation
import SwiftData

/// Tiny streak bookkeeper. Called after every `PlootTask.setDone(true)`.
///
/// Rules:
///   * A day "counts" once the user has done at least `dailyGoal` live
///     tasks that day (completedAt within local-today).
///   * Credit is recorded once per local-day via `streakLastDate`. If
///     lastDate == today, no-op.
///   * If lastDate == yesterday, bump streakCount by one.
///   * Otherwise reset to 1.
///
/// We don't decrement on undo / soft-delete — once credited, the day
/// stays credited. Adds complexity for marginal benefit (user would
/// have to un-done tasks until they drop below the goal).
@MainActor
enum StreakManager {
    static func bumpIfGoalHit(context: ModelContext) {
        guard UserPrefs.trackStreak else { return }

        let goal = UserPrefs.dailyGoal
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        // SwiftData's #Predicate doesn't accept unwrapping of optionals
        // in arithmetic comparisons cleanly across all toolchains, so
        // filter live/done in the predicate and the date range in Swift.
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate<PlootTask> { t in
                t.done == true && t.deletedAt == nil
            }
        )
        let doneTasks = (try? context.fetch(descriptor)) ?? []
        let completedTodayCount = doneTasks.filter { task in
            guard let c = task.completedAt else { return false }
            return c >= startOfDay && c < endOfDay
        }.count

        guard completedTodayCount >= goal else { return }

        let today = UserPrefs.dateKey()
        let last = UserPrefs.streakLastDate

        if last == today { return }

        let yesterday = UserPrefs.dateKey(for: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        let newCount: Int
        if last == yesterday {
            newCount = UserPrefs.streakCount + 1
        } else {
            newCount = 1
        }

        UserPrefs.setStreak(count: newCount, lastDate: today)
    }

    /// Used at app launch to decide whether the visible streak is still
    /// "alive" — if the user missed yesterday, the streak is effectively
    /// broken even though streakCount hasn't been decremented. The UI
    /// reads this to render 0 (or a "broken" indicator) without losing
    /// the persistent `streakCount` number.
    static var isStreakLive: Bool {
        let last = UserPrefs.streakLastDate
        guard !last.isEmpty else { return false }
        let cal = Calendar.current
        let today = UserPrefs.dateKey()
        if last == today { return true }
        let yesterday = UserPrefs.dateKey(for: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return last == yesterday
    }

    /// Display value — respects liveness.
    static var displayCount: Int {
        isStreakLive ? UserPrefs.streakCount : 0
    }
}
