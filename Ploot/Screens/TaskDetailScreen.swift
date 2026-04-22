import SwiftUI
import SwiftData

struct TaskDetailScreen: View {
    @Bindable var task: PlootTask

    @Query private var projects: [PlootProject]
    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editing: Bool = false
    @State private var confirmingDelete: Bool = false

    var body: some View {
        ScreenFrame(
            leading: {
                HeaderButton(systemImage: "arrow.left") { dismiss() }
            },
            trailing: { moreMenu }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleRow
                    chipRow
                        .padding(.top, Spacing.s5)
                        .padding(.leading, 46)
                    if let note = task.note, !note.isEmpty {
                        noteCard(note)
                    }
                    if !task.subtasks.isEmpty {
                        subtasksSection
                    }
                    metaFooter
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s2)
            }
        }
        .sheet(isPresented: $editing) {
            QuickAddSheet(existingTask: task, onClose: { editing = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .alert("Delete this task?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This can't be undone.")
        }
    }

    /// ••• menu in the top-right. Looks identical to the other HeaderButtons
    /// but wraps a Menu so taps reveal the action list.
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
        let taskToDelete = task
        ReminderService.shared.cancel(for: taskToDelete)
        dismiss()
        // Let the view unmount before freeing the model instance so the
        // @Bindable @Model doesn't read deleted properties on its way out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            modelContext.delete(taskToDelete)
            try? modelContext.save()
        }
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 14) {
            PlootCheckbox(
                checked: task.done,
                priority: task.priority,
                size: 32,
                onToggle: { task.setDone($0) }
            )
            .padding(.top, 4)

            Text(task.title)
                .font(.fraunces(size: 30, weight: 500, opsz: 100, soft: 40))
                .tracking(-0.015 * 30)
                .foregroundStyle(palette.fg1)
                .strikethrough(task.done)
                .opacity(task.done ? 0.5 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            if let dueLabel = TaskHelpers.displayLabel(for: task) {
                Chip(text: dueLabel, color: .clay, icon: "calendar")
            }
            if let project = TaskHelpers.project(id: task.projectId, from: projects) {
                Chip(text: project.name, color: .sky, icon: "folder")
            }
            if task.priority == .urgent {
                Chip(text: "Urgent", color: .plum, icon: "flame")
            }
            ForEach(task.tags, id: \.self) { tag in
                Chip(text: tag, color: .ink)
            }
        }
    }

    private func noteCard(_ note: String) -> some View {
        Text(note)
            .font(.geist(size: 15, weight: 400))
            .foregroundStyle(palette.fg1)
            .lineSpacing(15 * 0.55 - 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(radius: Radius.lg, padding: 16, fill: palette.butter100)
            .padding(.top, Spacing.s6)
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            let sorted = task.subtasks.sorted { $0.order < $1.order }
            let doneCount = sorted.filter { $0.done }.count
            Text("Sub-tasks · \(doneCount)/\(sorted.count)")
                .font(.jetBrainsMono(size: 11, weight: 600))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(palette.fg2)
                .padding(.bottom, 10)

            ForEach(sorted) { sub in
                HStack(spacing: Spacing.s3) {
                    PlootCheckbox(
                        checked: sub.done,
                        size: 20,
                        onToggle: { sub.setDone($0) }
                    )
                    Text(sub.title)
                        .font(.geist(size: 14, weight: 400))
                        .foregroundStyle(palette.fg1)
                        .strikethrough(sub.done)
                        .opacity(sub.done ? 0.5 : 1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(palette.border).frame(height: 1)
                }
            }
        }
        .padding(.top, 28)
    }

    private var metaFooter: some View {
        VStack(spacing: 10) {
            DetailRow(icon: "bell", label: "Remind me", value: "9:00 AM")
            DetailRow(icon: "repeat", label: "Repeats", value: task.repeats ?? "Never")
            DetailRow(icon: "paperclip", label: "Attachments", value: "None")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(palette.bgSunken)
        )
        .padding(.top, Spacing.s8)
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    @Environment(\.plootPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.fg3)
                .frame(width: 16)
            Text(label)
                .font(.geist(size: 14, weight: 400))
                .foregroundStyle(palette.fg2)
            Spacer()
            Text(value)
                .font(.geist(size: 14, weight: 500))
                .foregroundStyle(palette.fg1)
        }
    }
}

/// Minimal wrapping HStack — SwiftUI gained real flow layouts in iOS 16 via
/// the Layout protocol, but nothing ships with a `WrapHStack`. This measures
/// subview widths and wraps to next line when the current row overflows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: width)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: width == .infinity ? rows.map(\.width).max() ?? 0 : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.view.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [(view: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width && !row.items.isEmpty {
                rows.append(row)
                row = Row()
            }
            if row.items.isEmpty {
                row.items = [(sub, size)]
                row.width = size.width
            } else {
                row.items.append((sub, size))
                row.width += spacing + size.width
            }
            row.height = max(row.height, size.height)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
