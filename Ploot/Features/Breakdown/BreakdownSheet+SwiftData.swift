import SwiftUI
import SwiftData

// SwiftData mutations spawned by the breakdown stream: insert each task
// as it arrives, soft-delete via context menu, and the "this is a task"
// hint shortcut. Pulled out of BreakdownSheet.swift to isolate the
// timeline + ordering logic from view rendering.

extension BreakdownSheet {

    /// Timeline model: ONLY the first task (order=0) goes into Today with
    /// a dueDate stamped for this morning. The rest go into `.later` with
    /// no dueDate — they live in the project, invisible in Today, until
    /// the user completes the one in motion (see ProjectTaskPromoter,
    /// which promotes the next .later task when one completes).
    ///
    /// createdAt ordering: streamed tasks arrive 60ms apart, so task 0
    /// has the earliest createdAt and task N the latest. But Today
    /// screen sorts by createdAt DESC, which flips the visible order.
    /// To preserve the AI's intended order under a DESC sort, we backdate
    /// each task by `order × 1ms` so task 0 is the newest (appears
    /// first) and task N is the oldest (appears last).
    @discardableResult
    func insertTask(emoji: String, title: String, order: Int) -> UUID {
        let composed = "\(emoji) \(title)"
        let isFirst = order == 0
        let section: TaskSection = isFirst ? .today : .later
        let dueDate: Date? = isFirst ? Self.todayMorning() : nil
        let task = PlootTask(
            title: composed,
            dueDate: dueDate,
            projectId: project.id,
            section: section,
            remindMe: isFirst
        )
        // Stamp createdAt so DESC sort preserves AI task order.
        task.createdAt = baseCreatedAt.addingTimeInterval(-Double(order) * 0.001)
        task.updatedAt = task.createdAt
        modelContext.insert(task)
        try? modelContext.save()
        if isFirst {
            ReminderService.shared.schedule(for: task)
        }
        SyncService.shared.push(task: task)
        return task.id
    }

    static func todayMorning() -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .hour, value: 9, to: start) ?? start
    }

    func removeStreamedTask(_ streamed: StreamedTask) {
        // Soft-delete the real row so sync knows it's gone and the project
        // stops showing it. Then drop it from the sheet with a spring.
        let taskId = streamed.taskId
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            task.softDelete()
            try? modelContext.save()
        }
        withAnimation(Motion.spring) {
            streamedTasks.removeAll { $0.id == streamed.id }
            completedCount = max(0, completedCount - 1)
        }
    }

    /// User accepted the "this is a task, not a project" hint. Add the
    /// project title as a single task inside this project and close.
    func addAsSingleTask() {
        let task = PlootTask(
            title: project.name,
            projectId: project.id,
            section: .today
        )
        modelContext.insert(task)
        try? modelContext.save()
        SyncService.shared.push(task: task)
        closeSheet()
    }
}
