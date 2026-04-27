import SwiftUI
import SwiftData

struct ProjectsScreen: View {
    var onOpenProject: (PlootProject) -> Void

    @Query(sort: \PlootProject.order) private var projects: [PlootProject]
    @Query private var allTasks: [PlootTask]

    @State private var newProjectOpen: Bool = false
    @State private var editingProject: PlootProject? = nil
    @State private var deletingProject: PlootProject? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScreenFrame(
            title: "Projects",
            subtitle: "Where the plans live.",
            trailing: {
                HeaderButton(systemImage: "plus", action: { newProjectOpen = true })
            },
            content: {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        let liveProjects = projects.filter { $0.isLive }
                        if liveProjects.isEmpty {
                            EmptyState(
                                systemImage: "folder.badge.plus",
                                title: "No projects yet.",
                                subtitle: "Tap the + up top to spin up your first one."
                            )
                            .padding(.top, Spacing.s8)
                        } else {
                            ForEach(liveProjects) { project in
                                ProjectCard(
                                    project: project,
                                    openCount: openCount(for: project),
                                    doneCount: doneCount(for: project),
                                    onOpen: { onOpenProject(project) },
                                    onEdit: { editingProject = project },
                                    onDelete: { deletingProject = project }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.85)
                                        .combined(with: .opacity)
                                        .combined(with: .move(edge: .bottom)),
                                    removal: .scale(scale: 0.85)
                                        .combined(with: .opacity)
                                        .combined(with: .move(edge: .trailing))
                                ))
                            }
                        }
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s2)
                }
            }
        )
        .sheet(isPresented: $newProjectOpen) {
            NewProjectSheet(onClose: { newProjectOpen = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $editingProject) { project in
            NewProjectSheet(existingProject: project, onClose: { editingProject = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $deletingProject) { project in
            let count = taskCount(for: project.id)
            DeleteProjectSheet(
                project: project,
                taskCount: count,
                onKeepTasks: {
                    unassignTasks(ofProjectId: project.id)
                    withAnimation(Motion.spring) {
                        project.softDelete()
                        try? modelContext.save()
                    }
                    deletingProject = nil
                },
                onCascade: {
                    cascadeDeleteTasks(ofProjectId: project.id)
                    withAnimation(Motion.spring) {
                        project.softDelete()
                        try? modelContext.save()
                    }
                    deletingProject = nil
                },
                onCancel: { deletingProject = nil }
            )
            .presentationDetents([.height(count > 0 ? 420 : 320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private func openCount(for project: PlootProject) -> Int {
        allTasks.filter { $0.isLive && $0.projectId == project.id && !$0.done }.count
    }

    private func doneCount(for project: PlootProject) -> Int {
        allTasks.filter { $0.isLive && $0.projectId == project.id && $0.done }.count
    }

    private func taskCount(for projectId: String) -> Int {
        allTasks.filter { $0.isLive && $0.projectId == projectId }.count
    }

    /// "Keep tasks" path: mirror Supabase's ON DELETE SET NULL. Tasks
    /// referencing the project have projectId nulled and live on as
    /// inbox-style standalone work.
    private func unassignTasks(ofProjectId id: String) {
        for task in allTasks where task.isLive && task.projectId == id {
            task.projectId = nil
            task.touch()
        }
    }

    /// "Burn it all" path: soft-delete each task in the project so the
    /// tombstone propagates to Supabase and any scheduled reminder is
    /// canceled. Project soft-delete follows in the caller.
    private func cascadeDeleteTasks(ofProjectId id: String) {
        for task in allTasks where task.isLive && task.projectId == id {
            ReminderService.shared.cancel(for: task)
            task.softDelete()
        }
    }
}

private struct ProjectCard: View {
    let project: PlootProject
    let openCount: Int
    let doneCount: Int
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        let total = openCount + doneCount
        let pct = total == 0 ? 0 : Double(doneCount) / Double(total)

        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(spacing: Spacing.s3) {
                    Text(project.emoji)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(project.tileColor.fill(palette: palette))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(palette.borderInk, lineWidth: 2)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.geist(size: 16, weight: 600))
                            .tracking(-0.005 * 16)
                            .foregroundStyle(palette.fg1)

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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.fg3)
                }

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.bgSunken)
                        Capsule()
                            .fill(project.tileColor.dot(palette: palette))
                            .frame(width: pct * geo.size.width)
                    }
                }
                .frame(height: 5)
            }
            .cardStyle(radius: Radius.lg, padding: 14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
