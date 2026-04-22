import SwiftUI
import SwiftData

struct DoneScreen: View {
    var onOpen: (PlootTask) -> Void

    @Query(sort: \PlootTask.completedAt, order: .reverse) private var allTasks: [PlootTask]
    @Query private var projects: [PlootProject]

    @Environment(\.plootPalette) private var palette

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
                                onOpen: { onOpen(task) }
                            )
                        }
                    }
                    Color.clear.frame(height: 120)
                }
            }
        }
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 48))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(TaskHelpers.streak(from: allTasks))")
                    .font(.fraunces(size: 34, weight: 600))
                    .foregroundStyle(palette.onPrimary)
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
