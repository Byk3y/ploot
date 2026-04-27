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
        let openCount = tasks.filter { !$0.done }.count
        let doneCount = tasks.filter { $0.done }.count
        let total = openCount + doneCount
        let pct = total == 0 ? 0 : Double(doneCount) / Double(total)

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
                        Text("\(openCount) open")
                            .contentTransition(.numericText(value: Double(openCount)))
                        Circle().fill(palette.fg3).frame(width: 3, height: 3)
                        Text("\(doneCount) done")
                            .contentTransition(.numericText(value: Double(doneCount)))
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
                        .frame(width: pct * geo.size.width)
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
                BreakdownGhostRow(onTap: { breakingDown = true })
                    .padding(.horizontal, Spacing.s4)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                EmptyState(
                    systemImage: "tray",
                    title: "Nothing here yet.",
                    subtitle: "Tap + up top to add a task — or let the sparkle do it."
                )
            }
            .padding(.top, Spacing.s4)
        } else {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(tasks.sorted(by: Self.sortLess)) { task in
                        TaskRow(
                            task: task,
                            project: project,
                            onToggle: { task.setDone($0) },
                            onOpen: { editingTask = task },
                            onEdit: { editingTask = task },
                            onDelete: { deletingTask = task }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                } header: {
                    SectionHeader(title: "Tasks", count: tasks.count)
                }
            }
        }
    }

    /// Sort: open tasks first, then done tasks. Within each group:
    ///   - Open: tasks with a dueDate sort by dueDate ASC (soonest first).
    ///     Tasks without a dueDate sort AFTER dated ones, then by
    ///     createdAt DESC so the most recent insertions bubble to the
    ///     top. Breakdown stamps ordered tasks with sequential createdAts
    ///     so this preserves the AI's intended order.
    ///   - Done: by completedAt DESC.
    private static func sortLess(_ a: PlootTask, _ b: PlootTask) -> Bool {
        if a.done != b.done { return !a.done }
        if a.done {
            return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast)
        }
        switch (a.dueDate, b.dueDate) {
        case let (.some(ad), .some(bd)):
            if ad != bd { return ad < bd }
            return a.createdAt > b.createdAt
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none):
            return a.createdAt > b.createdAt
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
