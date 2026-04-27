import SwiftUI
import SwiftData

// Voice transcript → AI intent → SwiftData mutation pipeline. Pulled
// out of HomeView.swift because it has nothing to do with view layout —
// it routes the IntentService classification result into either a task
// insert, multi-task batch insert, project + auto-breakdown, or quick-add
// fallback.

extension HomeView {

    // MARK: - Intent routing

    func handleIntent(_ intent: VoiceIntent, originalTranscript: String) {
        switch intent {
        case .task(let t):
            let task = insertTask(t)
            var label = t.title
            if let due = t.dueDate { label += " · \(Self.shortDate(due))" }
            voiceToast = label
            voiceToastTaskId = task.id
            withAnimation(Motion.spring) { voicePhase = nil }
            scheduleToastDismiss()

        case .tasks(let list):
            for t in list { _ = insertTask(t) }
            voiceToast = "\(list.count) tasks added."
            voiceToastTaskId = nil
            withAnimation(Motion.spring) { voicePhase = nil }
            scheduleToastDismiss()

        case .project(let title):
            let project = insertProject(title: title)
            withAnimation(Motion.spring) { voicePhase = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                breakdownProject = project
            }

        case .ambiguous:
            fallbackToQuickAdd(transcript: originalTranscript, message: nil)
        }
    }

    func scheduleToastDismiss() {
        let current = voiceToast
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if voiceToast == current {
                withAnimation(Motion.spring) {
                    voiceToast = nil
                    voiceToastTaskId = nil
                }
            }
        }
    }

    // MARK: - SwiftData inserts

    @discardableResult
    func insertTask(_ t: VoiceTask) -> PlootTask {
        let projectId = resolveProjectSlug(t.projectSlug)
        let priority: Priority = {
            switch t.priority {
            case .urgent: return .urgent
            case .high: return .high
            case .normal, .none: return .normal
            }
        }()
        let task = PlootTask(
            title: t.title,
            dueDate: t.dueDate,
            projectId: projectId,
            priority: priority,
            section: Self.section(for: t.dueDate),
            remindMe: t.dueDate != nil
        )
        modelContext.insert(task)
        try? modelContext.save()
        ReminderService.shared.schedule(for: task)
        SyncService.shared.push(task: task)
        return task
    }

    /// Bucket by due date. Mirrors QuickAddSheet grouping logic.
    static func section(for dueDate: Date?) -> TaskSection {
        guard let dueDate else { return .today }
        let cal = Calendar.current
        if dueDate < Date().addingTimeInterval(-60) { return .overdue }
        if cal.isDateInToday(dueDate) { return .today }
        return .later
    }

    func resolveProjectSlug(_ slug: String?) -> String? {
        guard let slug, !slug.isEmpty else { return nil }
        return allProjects.first(where: { $0.id == slug && $0.isLive })?.id
    }

    @discardableResult
    func insertProject(title: String) -> PlootProject {
        let existingIds = Set(allProjects.map(\.id))
        let slug = Self.generateProjectSlug(from: title, existing: existingIds)
        let nextOrder = (allProjects.map(\.order).max() ?? 0) + 1
        let project = PlootProject(
            id: slug,
            name: title,
            emoji: "✨",
            tileColor: .primary,
            order: nextOrder
        )
        modelContext.insert(project)
        try? modelContext.save()
        SyncService.shared.push(project: project)
        return project
    }

    static func generateProjectSlug(from name: String, existing: Set<String>) -> String {
        let cleaned = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 -]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: "-", options: .regularExpression)
        let base = cleaned.isEmpty ? "project" : cleaned
        if !existing.contains(base) && base != "inbox" { return base }
        var n = 2
        while true {
            let candidate = "\(base)-\(n)"
            if !existing.contains(candidate) && candidate != "inbox" { return candidate }
            n += 1
        }
    }

    static func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    // MARK: - Fallback

    func fallbackToQuickAdd(transcript: String, message: String?) {
        let truncated = String(transcript.prefix(200))
        let task = PlootTask(title: truncated, section: .today)
        modelContext.insert(task)
        try? modelContext.save()
        SyncService.shared.push(task: task)

        voiceToast = message ?? truncated
        voiceToastTaskId = task.id
        scheduleToastDismiss()
        withAnimation(Motion.spring) { voicePhase = nil }
    }
}
