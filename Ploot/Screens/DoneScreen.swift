import SwiftUI
import SwiftData

struct DoneScreen: View {
    var onOpen: (PlootTask) -> Void

    @Query(sort: \PlootTask.completedAt, order: .reverse) private var allTasks: [PlootTask]
    @Query private var projects: [PlootProject]

    @AppStorage(UserPrefs.Key.dailyGoal) private var dailyGoal: Int = 5
    @AppStorage(UserPrefs.Key.streakRule) private var streakRuleRaw: String = UserPrefs.StreakRule.anyTask.rawValue

    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let done = TaskHelpers.doneTasks(from: allTasks)
        return ScreenFrame(
            title: "Done",
            subtitle: "Look at you go."
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    heroCard
                    SectionHeader(title: "Recently crushed", count: done.count)
                    if done.isEmpty {
                        EmptyState(
                            systemImage: "tray",
                            title: "Nothing yet.",
                            subtitle: "Check something off — any task counts."
                        )
                    } else {
                        ForEach(done) { task in
                            TaskRow(
                                task: task,
                                project: TaskHelpers.project(id: task.projectId, from: projects),
                                onToggle: { task.setDone($0) },
                                onOpen: { onOpen(task) },
                                onEdit: { editingTask = task },
                                onDelete: {
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
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                    Color.clear.frame(height: 120)
                }
            }
        }
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

    // MARK: - Hero card (single source of streak + week story)

    private var heroCard: some View {
        let rule = UserPrefs.StreakRule(rawValue: streakRuleRaw) ?? .anyTask
        let streak = TaskHelpers.streak(from: allTasks, rule: rule, dailyGoal: dailyGoal)
        let best = TaskHelpers.bestStreak(from: allTasks, rule: rule, dailyGoal: dailyGoal)
        let state = TaskHelpers.streakState(from: allTasks, rule: rule, dailyGoal: dailyGoal)
        let buckets = TaskHelpers.currentWeekCounts(from: allTasks)
        let weekTotal = buckets.map(\.count).reduce(0, +)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 10) {
                FireLottieView(isDimmed: state != .onFire)
                    .frame(width: 72, height: 72)
                streakHeader(
                    streak: streak,
                    best: best,
                    state: state,
                    weekTotal: weekTotal
                )
                Spacer(minLength: 0)
            }
            dotRow(buckets: buckets)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: Radius.lg, padding: 10)
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s1)
        .padding(.bottom, Spacing.s4)
    }

    @ViewBuilder
    private func streakHeader(
        streak: Int,
        best: Int,
        state: TaskHelpers.StreakState,
        weekTotal: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(streak)")
                .font(.fraunces(size: 32, weight: 600))
                .foregroundStyle(palette.fg1)
                .contentTransition(.numericText(value: Double(streak)))
            VStack(alignment: .leading, spacing: 2) {
                Text("day streak")
                    .font(.geist(size: 13, weight: 600))
                    .foregroundStyle(palette.fg1)
                Text(streakSubtitle(state: state, best: best, weekTotal: weekTotal))
                    .font(.jetBrainsMono(size: 10, weight: 600))
                    .foregroundStyle(streakSubtitleColor(state: state))
            }
        }
    }

    private func streakSubtitle(state: TaskHelpers.StreakState, best: Int, weekTotal: Int) -> String {
        let weekFragment = weekTotal == 0 ? "0 this week" : "\(weekTotal) this week"
        switch state {
        case .onFire:
            return best > 1 ? "\(weekFragment) · best \(best)" : weekFragment
        case .atRisk:
            return "secure it before midnight"
        case .cold:
            return weekTotal > 0 ? "\(weekFragment) · start a streak" : "start one today"
        }
    }

    private func streakSubtitleColor(state: TaskHelpers.StreakState) -> Color {
        switch state {
        case .onFire: return palette.fg3
        case .atRisk: return palette.clay500
        case .cold:   return palette.fg3
        }
    }

    @ViewBuilder
    private func dotRow(buckets: [TaskHelpers.DayBucket]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                DayDot(bucket: bucket)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    .animation(Motion.spring.delay(Double(index) * 0.04), value: bucket.count)
            }
        }
    }
}

// MARK: - Day dot

private struct DayDot: View {
    let bucket: TaskHelpers.DayBucket

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: 3) {
            Text(bucket.label)
                .font(.jetBrainsMono(size: 10, weight: bucket.isToday ? 700 : 500))
                .foregroundStyle(bucket.isToday ? palette.fg1 : palette.fg3)

            Circle()
                .fill(filled ? palette.clay300 : palette.bg)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .overlay(alignment: .center) {
                    if bucket.isToday {
                        Circle()
                            .fill(palette.fg1)
                            .frame(width: 6, height: 6)
                    } else if filled, bucket.count > 1 {
                        Text("\(bucket.count)")
                            .font(.jetBrainsMono(size: 9, weight: 700))
                            .foregroundStyle(palette.fg1)
                    }
                }
        }
    }

    private var filled: Bool { bucket.count > 0 }
}
