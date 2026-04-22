import SwiftUI

struct TaskDetailScreen: View {
    @Bindable var store: TaskStore
    let taskId: UUID

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var task: PlootTask? {
        store.tasks.first { $0.id == taskId }
    }

    var body: some View {
        if let task {
            ScreenFrame(
                leading: {
                    HeaderButton(systemImage: "arrow.left") { dismiss() }
                },
                trailing: {
                    HeaderButton(systemImage: "ellipsis", action: {})
                }
            ) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleRow(task)
                        chipRow(task)
                            .padding(.top, Spacing.s5)
                            .padding(.leading, 46)
                        if let note = task.note {
                            noteCard(note)
                        }
                        if !task.subtasks.isEmpty {
                            subtasksSection(task)
                        }
                        metaFooter(task)
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s2)
                }
            }
        } else {
            Color.clear
                .task { dismiss() }
        }
    }

    private func titleRow(_ task: PlootTask) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PlootCheckbox(
                checked: task.done,
                priority: task.priority,
                size: 32,
                onToggle: { store.toggle(task.id, done: $0) }
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

    private func chipRow(_ task: PlootTask) -> some View {
        FlowLayout(spacing: 8) {
            if let due = task.due {
                Chip(text: due, color: .clay, icon: "calendar")
            }
            if let project = store.project(id: task.projectId) {
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

    private func subtasksSection(_ task: PlootTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let doneCount = task.subtasks.filter { $0.done }.count
            Text("Sub-tasks · \(doneCount)/\(task.subtasks.count)")
                .font(.jetBrainsMono(size: 11, weight: 600))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(palette.fg2)
                .padding(.bottom, 10)

            ForEach(task.subtasks) { sub in
                HStack(spacing: Spacing.s3) {
                    PlootCheckbox(
                        checked: sub.done,
                        size: 20,
                        onToggle: { _ in store.toggleSubtask(taskId: task.id, subtaskId: sub.id) }
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

    private func metaFooter(_ task: PlootTask) -> some View {
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
