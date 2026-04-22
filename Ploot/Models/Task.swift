import Foundation
import SwiftData

// MARK: - Enums (stored as raw values in the model store)

enum Priority: String, CaseIterable, Codable, Identifiable {
    case normal, medium, high, urgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .medium: return "Medium"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    var emoji: String {
        switch self {
        case .normal: return ""
        case .medium: return "⚡"
        case .high:   return "❗"
        case .urgent: return "🔥"
        }
    }
}

enum TaskSection: String, Codable, CaseIterable {
    case overdue
    case today
    case later
    case done

    var displayTitle: String {
        switch self {
        case .overdue: return "Overdue"
        case .today:   return "Today"
        case .later:   return "Later this week"
        case .done:    return "Done"
        }
    }
}

// MARK: - Subtask model

@Model
final class Subtask {
    var id: UUID
    var title: String
    var done: Bool
    var order: Int
    var task: PlootTask?

    init(title: String, done: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.done = done
        self.order = order
    }
}

// MARK: - PlootTask model

@Model
final class PlootTask {
    var id: UUID
    var title: String
    var note: String?
    var due: String?
    var duration: String?
    /// References PlootProject.id (the String slug like "work", "home").
    /// Kept as a loose FK rather than a @Relationship because projects are
    /// identified by their slug, not by PersistentIdentifier.
    var projectId: String?
    var priority: Priority
    var tags: [String]
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task)
    var subtasks: [Subtask]
    var done: Bool
    var section: TaskSection
    var overdue: Bool
    var repeats: String?
    var createdAt: Date
    var completedAt: Date?

    init(
        title: String,
        note: String? = nil,
        due: String? = nil,
        duration: String? = nil,
        projectId: String? = nil,
        priority: Priority = .normal,
        tags: [String] = [],
        subtasks: [Subtask] = [],
        done: Bool = false,
        section: TaskSection = .today,
        overdue: Bool = false,
        repeats: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.due = due
        self.duration = duration
        self.projectId = projectId
        self.priority = priority
        self.tags = tags
        self.subtasks = subtasks
        self.done = done
        self.section = section
        self.overdue = overdue
        self.repeats = repeats
        self.createdAt = Date()
        self.completedAt = done ? Date() : nil
    }

    /// Apply a done/undone toggle with the side-effects needed for UI to
    /// stay consistent (section, timestamps).
    func setDone(_ value: Bool) {
        done = value
        if value {
            completedAt = Date()
            section = .done
        } else {
            completedAt = nil
            // When un-done, fall back to .today — overdue/later re-derivation
            // will come in Phase 3b once due dates are real Date values.
            if section == .done {
                section = .today
            }
        }
    }
}
