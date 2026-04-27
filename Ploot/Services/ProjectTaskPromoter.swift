import Foundation
import SwiftData

/// Auto-promotes the next `.later` task in a project into Today when the
/// user completes the one in motion. This is how AI-breakdown timelines
/// stay "one task active at a time" — the project always surfaces exactly
/// one next action, never the full 7-task list.
///
/// Heuristic for "next": the `.later` task in the same project with the
/// latest `createdAt`. BreakdownSheet stamps its tasks with backdated
/// timestamps (order 0 newest, order N oldest) — so the latest-createdAt
/// `.later` task is whichever one was next-in-line in the AI's original
/// ordering.
///
/// Only fires when the just-completed task has a projectId. Standalone
/// tasks (manual captures) are unaffected.
@MainActor
enum ProjectTaskPromoter {
    static func promoteNextIfNeeded(afterCompleting task: PlootTask, context: ModelContext) {
        guard let projectId = task.projectId else { return }

        // Fetch all live tasks in this project. We filter section +
        // completion state in Swift rather than #Predicate because
        // SwiftData predicate support for custom enums is spotty on
        // earlier iOS 17 builds.
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { candidate in
                candidate.projectId == projectId
                    && candidate.deletedAt == nil
                    && candidate.done == false
            }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []
        let next = candidates
            .filter { $0.section == .later }
            .sorted { $0.createdAt > $1.createdAt }
            .first
        guard let next else { return }
        // If the user already scheduled this task via the breakdown
        // timeline picker, leave its dueDate alone — promoting it to
        // "today, 30 minutes from now" would silently overwrite their
        // intent. The task will surface naturally when its date hits.
        if next.dueDate != nil { return }

        next.section = .today
        next.dueDate = nextSensibleDueDate()
        next.remindMe = true
        next.touch()
        try? context.save()
        ReminderService.shared.schedule(for: next)
        SyncService.shared.push(task: next)
    }

    /// Always strictly in the future so reminders fire and the displayed
    /// time isn't already past. Mirrors `BreakdownSheet.firstTaskDueDate`.
    private static func nextSensibleDueDate(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let nineAM = cal.date(byAdding: .hour, value: 9, to: startOfToday) ?? startOfToday
        if now < nineAM { return nineAM }
        let minute = cal.component(.minute, from: now)
        let bump = minute < 30 ? (30 - minute) : (60 - minute)
        let rounded = cal.date(byAdding: .minute, value: bump, to: now) ?? now
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        return cal.date(from: comps) ?? rounded
    }
}
