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

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let tasks = allTasks.filter { $0.projectId == project.id }
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
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
        }
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .alert("Delete this project?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("Tasks in this project will stay, but lose their project label.")
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
                        Circle().fill(palette.fg3).frame(width: 3, height: 3)
                        Text("\(doneCount) done")
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
            EmptyState(
                systemImage: "tray",
                title: "Nothing here yet.",
                subtitle: "Tap + up top to add a task to \(project.name)."
            )
            .padding(.top, Spacing.s4)
        } else {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(tasks.sorted { ordering($0) < ordering($1) }) { task in
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

    /// Sort order: open tasks first (by dueDate nulls last, then created
    /// desc), then done tasks (by completedAt desc).
    private func ordering(_ task: PlootTask) -> (Int, Date) {
        if task.done {
            return (1, task.completedAt ?? .distantPast)
        }
        return (0, task.dueDate ?? .distantFuture)
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

    private func performDelete() {
        let projectToDelete = project
        let idToDelete = project.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Mirror Supabase's ON DELETE SET NULL: null out projectId on any
            // task that referenced this project, then delete the project
            // itself. Tasks keep all other content.
            let fetch = FetchDescriptor<PlootTask>()
            let tasks = (try? modelContext.fetch(fetch)) ?? []
            for task in tasks where task.projectId == idToDelete {
                task.projectId = nil
                task.touch()
            }
            modelContext.delete(projectToDelete)
            try? modelContext.save()
        }
    }
}
