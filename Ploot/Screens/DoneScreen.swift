import SwiftUI
import SwiftData

struct DoneScreen: View {
    var onOpen: (PlootTask) -> Void

    @Query(sort: \PlootTask.completedAt, order: .reverse) private var allTasks: [PlootTask]
    @Query private var projects: [PlootProject]

    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let done = TaskHelpers.doneTasks(from: allTasks)
        return ScreenFrame(
            title: "Done",
            subtitle: "\(done.count) this week. Look at you go."
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    streakCard
                    weeklyChart
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
                                onDelete: { deletingTask = task }
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
                    modelContext.delete(task)
                    try? modelContext.save()
                }
                deletingTask = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var streakCard: some View {
        let streak = TaskHelpers.streak(from: allTasks)
        return HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 48))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak)")
                    .font(.fraunces(size: 34, weight: 600))
                    .foregroundStyle(palette.onPrimary)
                    .contentTransition(.numericText(value: Double(streak)))
                Text("day streak · don't break it")
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.onPrimary.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: Radius.lg, padding: 18, fill: palette.primary)
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s1)
        .padding(.bottom, Spacing.s4)
    }

    private var weeklyChart: some View {
        let buckets = TaskHelpers.weeklyCounts(from: allTasks)
        let maxCount = max(buckets.map(\.count).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: Spacing.s2) {
            ForEach(buckets) { bucket in
                VStack(spacing: 4) {
                    // Height scales proportionally to the tallest bar so the
                    // chart reads even on a quiet week. Floor at 12pt so zero
                    // counts still render as a visible stub.
                    let normalized = CGFloat(bucket.count) / CGFloat(maxCount)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(bucket.isToday ? palette.primary : palette.clay200)
                        .frame(height: normalized * 64 + 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderInk, lineWidth: 2)
                        )

                    Text(bucket.label)
                        .font(.jetBrainsMono(size: 11, weight: bucket.isToday ? 700 : 500))
                        .foregroundStyle(bucket.isToday ? palette.fg1 : palette.fg3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s2)
    }
}
