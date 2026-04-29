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
    @AppStorage(UserPrefs.Key.streakRule) private var streakRuleRaw: String = UserPrefs.StreakRule.anyTask.rawValue
    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScreenFrame(
            title: "Ploot",
            trailing: { trailingAvatar },
            content: { list }
        )
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
        }
        .alert("Delete this task?", isPresented: .init(
            get: { deletingTask != nil },
            set: { if !$0 { deletingTask = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingTask = nil }
            Button("Delete", role: .destructive) {
                if let task = deletingTask {
                    ReminderService.shared.cancel(for: task)
                    withAnimation(Motion.spring) {
                        task.softDelete()
                        try? modelContext.save()
                    }
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                progressStrip
                let activeSteps = TaskHelpers.activeProjectSteps(from: allTasks, projects: projects)
                let activeStepIDs = Set(activeSteps.map { $0.task.id })

                if !activeSteps.isEmpty {
                    Section {
                        ForEach(activeSteps) { item in
                            TodayNextStepCard(
                                task: item.task,
                                project: item.project,
                                progress: item.progress,
                                onToggle: { item.task.setDone($0) },
                                onOpen: { onOpen(item.task) }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    } header: {
                        SectionHeader(title: "Next steps", count: activeSteps.count)
                    }
                }

                let overdue = TaskHelpers.tasks(in: .overdue, from: allTasks)
                    .filter { !activeStepIDs.contains($0.id) }
                let todayBucket = TaskHelpers.tasks(in: .today, from: allTasks)
                    .filter { !activeStepIDs.contains($0.id) }
                let showOverdueSection = UserPrefs.showOverdueSeparately && !overdue.isEmpty

                if showOverdueSection {
                    Section {
                        ForEach(overdue) { row($0) }
                    } header: {
                        SectionHeader(title: "Overdue", count: overdue.count)
                    }
                }

                // When the user has opted to merge overdue into Today
                // (Settings → Today → Show overdue separately = off),
                // tack overdue onto the front of the today list so it
                // still appears at the top of the section.
                let today: [PlootTask] = showOverdueSection
                    ? todayBucket
                    : overdue + todayBucket
                if !today.isEmpty || activeSteps.isEmpty {
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
                }

                let later = TaskHelpers.tasks(in: .later, from: allTasks)
                    .filter { !activeStepIDs.contains($0.id) }
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

        let rule = UserPrefs.StreakRule(rawValue: streakRuleRaw) ?? .anyTask
        let streakCount = TaskHelpers.streak(from: allTasks, rule: rule, dailyGoal: dailyGoal)
        let streakState = TaskHelpers.streakState(from: allTasks, rule: rule, dailyGoal: dailyGoal)

        return HStack(alignment: .center, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 6) {
                streakHeader(count: streakCount, state: streakState)
                ProgressBar(value: pct)
            }
            if trackStreak {
                PlootMascotView(state: streakState, isDimmed: streakState != .onFire)
                    .frame(width: 56, height: 56)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s4)
    }

    /// Hero label for the progress strip. Replaces the older "1 of 3"
    /// daily count — the bar already shows that visually. The streak
    /// is the more meaningful narrative, so it gets the prominent
    /// number slot. Fire signifies "streak", count is the number,
    /// "day streak" makes it concrete.
    ///
    /// Uses `.center` alignment because Lottie views don't expose a
    /// text baseline — `.firstTextBaseline` dropped the flame to a
    /// second line.
    @ViewBuilder
    private func streakHeader(count: Int, state: TaskHelpers.StreakState) -> some View {
        let isOnFire = state == .onFire
        HStack(alignment: .center, spacing: 6) {
            FireLottieView(isDimmed: !isOnFire)
                .frame(width: 44, height: 44)
            Text("\(count)")
                .font(.fraunces(size: 28, weight: 600, opsz: 72, soft: 40))
                .foregroundStyle(isOnFire ? palette.clay500 : palette.fg1)
                .contentTransition(.numericText(value: Double(count)))
                .animation(Motion.spring, value: count)
            Text("day streak")
                .font(.geist(size: 13, weight: 500))
                .foregroundStyle(isOnFire ? palette.clay500 : palette.fg3)
                .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private func row(_ task: PlootTask) -> some View {
        TaskRow(
            task: task,
            project: TaskHelpers.project(id: task.projectId, from: projects),
            onToggle: { task.setDone($0) },
            onOpen: { onOpen(task) },
            onEdit: { editingTask = task },
            onDelete: { requestDelete(task) },
            onRescheduleToday: { rescheduleToToday(task) }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }

    /// Route a delete tap through the user's "confirm before delete"
    /// preference. When confirm is on, opens the alert; when off,
    /// softDeletes immediately (still animated, still cancels the
    /// reminder, still pushes the tombstone).
    private func requestDelete(_ task: PlootTask) {
        if UserPrefs.confirmBeforeDelete {
            deletingTask = task
        } else {
            ReminderService.shared.cancel(for: task)
            withAnimation(Motion.spring) {
                task.softDelete()
                try? modelContext.save()
            }
        }
    }

    /// Push the task's dueDate forward — to *today* when it's a past-day
    /// overdue task, or to *tomorrow* when it's same-day late (already
    /// today, just past the time). Either way, time-of-day is preserved
    /// so a "9 am call" stays at 9 am, just on a later day.
    private func rescheduleToToday(_ task: PlootTask) {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)

        // Same-day past-time tasks have no `lateLabel` (it returns nil
        // for that case) — those push to tomorrow. Past-day overdue
        // tasks push to today.
        let isSameDayLate = task.dueDate.map { due in
            cal.isDate(due, inSameDayAs: now) && due < now
        } ?? false
        let targetDay: Date = {
            if isSameDayLate {
                return cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            }
            return startOfToday
        }()

        let newDate: Date
        if let original = task.dueDate {
            let h = cal.component(.hour, from: original)
            let m = cal.component(.minute, from: original)
            newDate = cal.date(bySettingHour: h, minute: m, second: 0, of: targetDay) ?? targetDay
        } else {
            newDate = targetDay
        }

        withAnimation(Motion.spring) {
            task.dueDate = newDate
            // Past-day → today section. Same-day-late pushed to
            // tomorrow → later section.
            task.section = isSameDayLate ? .later : .today
            task.touch()
            try? modelContext.save()
        }
        ReminderService.shared.schedule(for: task)
        SyncService.shared.push(task: task)
    }

}

private struct TodayNextStepCard: View {
    let task: PlootTask
    let project: PlootProject
    let progress: TaskHelpers.ProjectProgress
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var justCompleted = false

    private var showAsDone: Bool { task.done || justCompleted }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .top, spacing: 10) {
                    PlootCheckbox(
                        checked: showAsDone,
                        priority: task.priority,
                        size: 24,
                        onToggle: handleToggle
                    )
                    .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(project.emoji)
                                .font(.system(size: 14))
                            Text(project.name)
                                .font(.jetBrainsMono(size: 11, weight: 700))
                                .tracking(11 * 0.08)
                                .textCase(.uppercase)
                                .foregroundStyle(palette.fg2)
                                .lineLimit(1)
                        }

                        Text(task.title.strippingLeadingEmoji())
                            .font(.geist(size: 15, weight: 600))
                            .foregroundStyle(palette.fg1)
                            .strikethrough(showAsDone, color: palette.fg2)
                            .opacity(showAsDone ? 0.5 : 1)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Text("step \(min(progress.done + 1, progress.total)) of \(progress.total) · queued for today")
                                .contentTransition(.numericText(value: Double(progress.done)))
                        }
                        .font(.geist(size: 12, weight: 500))
                        .foregroundStyle(palette.fg3)
                    }

                    Spacer(minLength: 0)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.bgSunken)
                        Capsule()
                            .fill(project.tileColor.dot(palette: palette))
                            .frame(width: progress.fraction * geo.size.width)
                    }
                }
                .frame(height: 5)
            }
            .cardStyle(radius: Radius.lg, padding: 12)
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .animation(Motion.spring, value: showAsDone)
    }

    private func handleToggle(_ value: Bool) {
        if value {
            justCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(Motion.spring) {
                    onToggle(true)
                }
            }
        } else {
            withAnimation(Motion.spring) {
                onToggle(false)
            }
        }
    }
}

extension String {
    func strippingLeadingEmoji() -> String {
        return self.replacingOccurrences(
            of: "^(\\s*[\\p{Emoji_Presentation}\\p{Extended_Pictographic}]\\s*)+",
            with: "",
            options: .regularExpression
        )
    }
}
