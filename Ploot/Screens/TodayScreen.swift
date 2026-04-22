import SwiftUI
import SwiftData

struct TodayScreen: View {
    var onOpen: (PlootTask) -> Void
    var onOpenSettings: () -> Void

    @Query(sort: \PlootTask.createdAt, order: .reverse) private var allTasks: [PlootTask]
    @Query(sort: \PlootProject.order) private var projects: [PlootProject]

    @Environment(\.plootPalette) private var palette

    var body: some View {
        ScreenFrame(
            title: "Today",
            titleSuffix: AnyView(todaySuffix),
            subtitle: TaskHelpers.todaySubtitle(from: allTasks),
            trailing: { trailingAvatar },
            content: { list }
        )
    }

    private var trailingAvatar: some View {
        Button(action: onOpenSettings) {
            Text("LM")
                .font(.geist(size: 13, weight: 700))
                .foregroundStyle(palette.ink800)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.butter300))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var todaySuffix: some View {
        Text(" · \(Self.dateText())")
            .font(.fraunces(size: 22, weight: 400, opsz: 22, soft: 100, italic: true))
            .foregroundStyle(palette.fg3)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                progressStrip
                let overdue = TaskHelpers.tasks(in: .overdue, from: allTasks)
                if !overdue.isEmpty {
                    Section {
                        ForEach(overdue) { row($0) }
                    } header: {
                        SectionHeader(title: "Overdue", count: overdue.count)
                    }
                }

                let today = TaskHelpers.tasks(in: .today, from: allTasks)
                Section {
                    if today.isEmpty {
                        EmptyState(
                            systemImage: "flag.checkered",
                            title: "All done!",
                            subtitle: "You finished today's list. Take a victory lap — you've earned it."
                        )
                    } else {
                        ForEach(today) { row($0) }
                    }
                } header: {
                    SectionHeader(title: "Today", count: today.count)
                }

                let later = TaskHelpers.tasks(in: .later, from: allTasks)
                if !later.isEmpty {
                    Section {
                        ForEach(later) { row($0) }
                    } header: {
                        SectionHeader(title: "Later this week", count: later.count)
                    }
                }

                Color.clear.frame(height: 120)
            }
        }
    }

    private var progressStrip: some View {
        let today = TaskHelpers.tasks(in: .today, from: allTasks)
        let total = today.count
        let done = today.filter { $0.done }.count
        return ProgressBar(value: total == 0 ? 0 : Double(done) / Double(total))
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, Spacing.s4)
    }

    @ViewBuilder
    private func row(_ task: PlootTask) -> some View {
        TaskRow(
            task: task,
            project: TaskHelpers.project(id: task.projectId, from: projects),
            onToggle: { task.setDone($0) },
            onOpen: { onOpen(task) }
        )
    }

    private static func dateText() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: Date())
    }
}
