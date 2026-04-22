import Foundation
import Observation

@Observable
final class TaskStore {
    var tasks: [PlootTask]
    var projects: [PlootProject]

    init(tasks: [PlootTask] = DemoData.tasks(), projects: [PlootProject] = DemoData.projects) {
        self.tasks = tasks
        self.projects = projects
    }

    // MARK: - Queries

    func tasks(in section: TaskSection) -> [PlootTask] {
        tasks.filter { $0.section == section }
    }

    var doneTasks: [PlootTask] { tasks.filter { $0.done } }

    func project(id: String?) -> PlootProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: - Mutations

    func toggle(_ id: UUID, done: Bool) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].done = done
        if done {
            tasks[idx].section = .done
        }
    }

    func toggleSubtask(taskId: UUID, subtaskId: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskId }),
              let si = tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskId }) else { return }
        tasks[ti].subtasks[si].done.toggle()
    }

    func add(_ task: PlootTask) {
        tasks.insert(task, at: 0)
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    // MARK: - Stats

    var streak: Int { 7 } // TODO: real streak math once persistence lands

    var weeklyCounts: [Int] {
        // Demo-shaped until we wire persistence. Trailing day = today's count.
        [3, 5, 2, 7, 4, 6, max(1, tasks(in: .done).count)]
    }
}
