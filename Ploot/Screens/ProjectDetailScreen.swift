import SwiftUI
import SwiftData

/// Full-screen detail for a single project. Tapping a ProjectCard on the
/// Projects tab pushes this screen. Shows a large header with live counts,
/// a filtered task list, a `+` to create a task pre-scoped to this project,
/// and a `•••` menu for Edit / Delete project.
struct ProjectDetailScreen: View {
    @Bindable var project: PlootProject

    @Query private var allTasks: [PlootTask]
    @Query(sort: \PlootProject.order) private var allProjects: [PlootProject]

    @State private var editing: Bool = false
    @State private var confirmingDelete: Bool = false
    @State private var addingTask: Bool = false
    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil
    @State private var breakingDown: Bool = false

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let tasks = allTasks.filter { $0.isLive && $0.projectId == project.id }
        return ScreenFrame(
            leading: {
                HeaderButton(systemImage: "arrow.left") { dismiss() }
            },
            trailing: {
                HStack(spacing: Spacing.s2) {
                    if UserPrefs.useAIBreakdown {
                        HeaderButton(systemImage: "sparkles") { breakingDown = true }
                    }
                    HeaderButton(systemImage: "plus") { addingTask = true }
                    moreMenu
                }
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    projectHeader(tasks: tasks)
                    taskList(tasks: tasks)
                    Color.clear.frame(height: 80)
                }
            }
        }
        .sheet(isPresented: $editing) {
            NewProjectSheet(existingProject: project, onClose: { editing = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $addingTask) {
            QuickAddSheet(
                initialProjectId: project.id,
                onClose: { addingTask = false }
            )
        }
        .sheet(isPresented: $breakingDown) {
            BreakdownSheet(project: project, onClose: { breakingDown = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
        }
        .sheet(isPresented: $confirmingDelete) {
            let count = liveTaskCount
            DeleteProjectSheet(
                project: project,
                taskCount: count,
                onKeepTasks: {
                    confirmingDelete = false
                    performDelete(cascade: false)
                },
                onCascade: {
                    confirmingDelete = false
                    performDelete(cascade: true)
                },
                onCancel: { confirmingDelete = false }
            )
            .presentationDetents([.height(count > 0 ? 420 : 320)])
            .presentationDragIndicator(.visible)
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

    // MARK: - Header

    private func projectHeader(tasks: [PlootTask]) -> some View {
        let progress = TaskHelpers.projectProgress(for: project, from: tasks)

        return VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(alignment: .center, spacing: Spacing.s4) {
                Text(project.emoji)
                    .font(.system(size: 32))
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(project.tileColor.fill(palette: palette))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2)
                    )
                    .stampedShadow(radius: 16, offset: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.fraunces(size: 28, weight: 600, opsz: 100, soft: 40))
                        .tracking(-0.015 * 28)
                        .foregroundStyle(palette.fg1)
                        .lineLimit(2)
                    HStack(spacing: Spacing.s2) {
                        Text("\(progress.open) open")
                            .contentTransition(.numericText(value: Double(progress.open)))
                        Circle().fill(palette.fg3).frame(width: 3, height: 3)
                        Text("\(progress.done) done")
                            .contentTransition(.numericText(value: Double(progress.done)))
                    }
                    .font(.geist(size: 13, weight: 400))
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
                .overlay(Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5))
            }
            .frame(height: 8)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s5)
    }

    // MARK: - Task list

    @ViewBuilder
    private func taskList(tasks: [PlootTask]) -> some View {
        if tasks.isEmpty {
            VStack(spacing: Spacing.s4) {
                EmptyState(
                    systemImage: "tray",
                    title: "Nothing here yet.",
                    subtitle: UserPrefs.useAIBreakdown
                        ? "Tap + up top to add a task — or let the sparkle do it."
                        : "Tap + up top to add a task to this project."
                ) {
                    if UserPrefs.useAIBreakdown {
                        Button {
                            breakingDown = true
                        } label: {
                            Label("Break down project", systemImage: "sparkles")
                        }
                        .buttonStyle(.plootPrimary)
                        .padding(.top, Spacing.s2)
                    }
                }
            }
            .padding(.top, Spacing.s4)
        } else {
            let progress = TaskHelpers.projectProgress(for: project, from: allTasks)
            let open = tasks
                .filter { !$0.done }
                .sorted(by: TaskHelpers.projectStepSortLess)
            let current = open.first
            let upcoming = Array(open.dropFirst())
            let done = tasks
                .filter(\.done)
                .sorted(by: TaskHelpers.projectStepSortLess)

            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if let current {
                    Section {
                        CurrentProjectStepCard(
                            task: current,
                            project: project,
                            progress: progress,
                            onToggle: { current.setDone($0) },
                            onOpen: { editingTask = current }
                        )
                        .padding(.horizontal, Spacing.s4)
                        .padding(.bottom, Spacing.s4)
                    } header: {
                        SectionHeader(title: "Current step", count: 1)
                    }
                }

                if !upcoming.isEmpty {
                    Section {
                        ForEach(upcoming) { task in
                            taskRow(task)
                        }
                    } header: {
                        SectionHeader(title: "Upcoming", count: upcoming.count)
                    }
                }

                if !done.isEmpty {
                    Section {
                        ForEach(done) { task in
                            taskRow(task)
                        }
                    } header: {
                        SectionHeader(title: "Done", count: done.count)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: PlootTask) -> some View {
        TaskRow(
            task: task,
            project: project,
            onToggle: { task.setDone($0) },
            onOpen: { editingTask = task },
            onEdit: { editingTask = task },
            onDelete: { requestDelete(task) }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }

    /// Route a task delete through the user's "Confirm before delete"
    /// preference. Mirror of TodayScreen + DoneScreen so the toggle
    /// behaves the same everywhere a task can be deleted via the row
    /// menu.
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

    // MARK: - More menu

    private var moreMenu: some View {
        Menu {
            Button {
                editing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            if UserPrefs.useAIBreakdown {
                Button {
                    breakingDown = true
                } label: {
                    Label("Break down more", systemImage: "sparkles")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.fg1)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.bgElevated))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))
        }
        .menuStyle(.button)
    }

    private var liveTaskCount: Int {
        allTasks.filter { $0.isLive && $0.projectId == project.id }.count
    }

    /// Two paths:
    ///   - cascade=false: mirror Supabase's ON DELETE SET NULL, null out
    ///     projectId on every task that referenced this project. Tasks
    ///     keep all other content.
    ///   - cascade=true: soft-delete each task too, canceling its reminder
    ///     and propagating the tombstone to Supabase. Use when the user
    ///     explicitly opts to throw the work away with the project.
    private func performDelete(cascade: Bool) {
        let projectToDelete = project
        let idToDelete = project.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let fetch = FetchDescriptor<PlootTask>()
            let tasks = (try? modelContext.fetch(fetch)) ?? []
            for task in tasks where task.isLive && task.projectId == idToDelete {
                if cascade {
                    ReminderService.shared.cancel(for: task)
                    task.softDelete()
                } else {
                    task.projectId = nil
                    task.touch()
                }
            }
            projectToDelete.softDelete()
            try? modelContext.save()
        }
    }
}

private struct CurrentProjectStepCard: View {
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
                HStack(alignment: .top, spacing: Spacing.s3) {
                    PlootCheckbox(
                        checked: showAsDone,
                        priority: task.priority,
                        size: 30,
                        onToggle: handleToggle
                    )
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("start here")
                            .font(.jetBrainsMono(size: 11, weight: 700))
                            .tracking(11 * 0.08)
                            .textCase(.uppercase)
                            .foregroundStyle(project.tileColor.dot(palette: palette))

                        Text(task.title)
                            .font(.fraunces(size: 23, weight: 500, opsz: 40, soft: 50))
                            .tracking(-0.01 * 23)
                            .foregroundStyle(palette.fg1)
                            .strikethrough(showAsDone, color: palette.fg2)
                            .opacity(showAsDone ? 0.5 : 1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(progress.done) of \(progress.total) steps done. keep it small.")
                            .font(.geist(size: 13, weight: 500))
                            .foregroundStyle(palette.fg3)
                            .contentTransition(.numericText(value: Double(progress.done)))
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
                    .overlay(Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5))
                }
                .frame(height: 7)
            }
            .cardStyle(radius: Radius.lg, padding: 16)
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
