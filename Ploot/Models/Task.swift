import Foundation

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

enum TaskSection: String, Codable {
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

struct Subtask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
}

struct PlootTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var note: String? = nil
    var due: String? = nil
    var duration: String? = nil
    var projectId: String? = nil
    var priority: Priority = .normal
    var tags: [String] = []
    var subtasks: [Subtask] = []
    var done: Bool = false
    var section: TaskSection = .today
    var overdue: Bool = false
    var repeats: String? = nil
}
