import SwiftUI
import SwiftData

struct TodayScreen: View {
    var onOpen: (PlootTask) -> Void
    var onOpenSettings: () -> Void

    @Query(sort: \PlootTask.createdAt, order: .reverse) private var allTasks: [PlootTask]
    @Query(sort: \PlootProject.order) private var projects: [PlootProject]

    @AppStorage("displayName") private var displayName: String = "You"
    @AppStorage(UserPrefs.Key.dailyGoal) private var dailyGoal: Int = 5
    @AppStorage(UserPrefs.Key.trackStreak) private var trackStreak: Bool = true
    @AppStorage(UserPrefs.Key.streakCount) private var streakCount: Int = 0
    @AppStorage(UserPrefs.Key.streakLastDate) private var streakLastDate: String = ""
    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScreenFrame(
            title: "Today",
            titleSuffix: AnyView(todaySuffix),
            subtitle: TaskHelpers.todaySubtitle(from: allTasks),
            trailing: { trailingAvatar },
            content: { list }
        )
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .alert("Delete this task?", isPresented: .init(
            get: { deletingTask != nil },
            set: { if !$0 { deletingTask = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingTask = nil }
            Button("Delete", role: .destructive) {
                if let task = deletingTask {
                    ReminderService.shared.cancel(for: task)
                    task.softDelete()
                    try? modelContext.save()
                }
                deletingTask = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var trailingAvatar: some View {
        Button(action: onOpenSettings) {
            Text(TaskHelpers.avatarInitials(for: displayName))
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
        // Progress is done-today vs. the user's daily goal (not vs. the
        // raw list size). Their list might have 14 tasks; their goal
        // might be 5. Once they hit 5 they see "done!", overflow is a
        // bonus. Count only tasks completed today, not stale .done rows.
        let doneToday = TaskHelpers.completedToday(from: allTasks)
        let goal = max(1, dailyGoal)
        let pct = min(1.0, Double(doneToday) / Double(goal))

        return VStack(spacing: Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(doneToday)")
                        .font(.fraunces(size: 28, weight: 600, opsz: 72, soft: 40))
                        .foregroundStyle(palette.fg1)
                        .contentTransition(.numericText())
                        .animation(Motion.spring, value: doneToday)
                    Text("of \(goal) crushed")
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                if trackStreak {
                    streakChip
                }
            }
            ProgressBar(value: pct)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s4)
    }

    private var streakChip: some View {
        // Live-streak logic mirrors StreakManager.displayCount but we
        // compute inline so the @AppStorage observation triggers redraws
        // when streakLastDate changes.
        let displayCount: Int = {
            guard !streakLastDate.isEmpty else { return 0 }
            let today = UserPrefs.dateKey()
            if streakLastDate == today { return streakCount }
            let yesterday = UserPrefs.dateKey(
                for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            )
            return streakLastDate == yesterday ? streakCount : 0
        }()

        return HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 14))
                .opacity(displayCount > 0 ? 1 : 0.35)
            Text("\(displayCount)")
                .font(.geist(size: 13, weight: 700))
                .foregroundStyle(displayCount > 0 ? palette.fg1 : palette.fg3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(palette.bgElevated)
        )
        .overlay(
            Capsule().strokeBorder(palette.border, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func row(_ task: PlootTask) -> some View {
        TaskRow(
            task: task,
            project: TaskHelpers.project(id: task.projectId, from: projects),
            onToggle: { task.setDone($0) },
            onOpen: { onOpen(task) },
            onEdit: { editingTask = task },
            onDelete: { deletingTask = task }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }

    private static func dateText() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: Date())
    }
}
