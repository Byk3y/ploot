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

        next.section = .today
        next.dueDate = todayMorning()
        next.remindMe = true
        next.touch()
        try? context.save()
        ReminderService.shared.schedule(for: next)
        SyncService.shared.push(task: next)
    }

    private static func todayMorning() -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .hour, value: 9, to: start) ?? start
    }
}
