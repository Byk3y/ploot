import SwiftUI

struct TaskRow: View {
    var task: PlootTask
    var project: PlootProject?
    var onToggle: (Bool) -> Void
    var onOpen: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.plootPalette) private var palette
    /// Local predictive flag — flipped the instant the user taps the
    /// checkbox so the strikethrough shows before the actual setDone()
    /// mutation (which also removes the row from the Today filter) is
    /// committed ~550ms later.
    @State private var justCompleted: Bool = false

    /// Either side can drive the "done" visual: the persisted task state
    /// (already done), or the local just-tapped prediction (mid-animation).
    private var showAsDone: Bool { task.done || justCompleted }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                PlootCheckbox(
                    checked: showAsDone,
                    priority: task.priority,
                    size: 24,
                    onToggle: handleToggle
                )
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.geist(size: 15, weight: 500))
                        .tracking(-0.005 * 15)
                        .strikethrough(showAsDone, color: palette.fg2)
                        .foregroundStyle(palette.fg1)
                        .opacity(showAsDone ? 0.5 : 1)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if hasMeta {
                        metaRow
                    }
                }

                Spacer(minLength: 0)

                // Priority indicator — ⚡ medium, ❗ high, 🔥 urgent. Hidden
                // on done tasks (and on predictively-done ones during the
                // slide-out) so the list doesn't scream at you about things
                // you've already crushed.
                if !task.priority.emoji.isEmpty && !showAsDone {
                    Text(task.priority.emoji)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgElevated)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(Motion.spring, value: showAsDone)
        .contextMenu {
            Button {
                onToggle(!task.done)
            } label: {
                Label(task.done ? "Mark as not done" : "Mark as done",
                      systemImage: task.done ? "circle" : "checkmark.circle")
            }
            if let onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var hasMeta: Bool {
        TaskHelpers.displayLabel(for: task) != nil || task.projectId != nil || !task.tags.isEmpty
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            if let dueLabel = TaskHelpers.displayLabel(for: task) {
                let isOverdue = TaskHelpers.derivedSection(for: task) == .overdue
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(dueLabel)
                        .font(.geist(size: 12, weight: 500))
                }
                .foregroundStyle(isOverdue ? palette.danger : palette.fg2)
            }

            if let project {
                HStack(spacing: 4) {
                    Circle()
                        .fill(project.tileColor.dot(palette: palette))
                        .frame(width: 6, height: 6)
                    Text(project.name)
                        .font(.geist(size: 12, weight: 500))
                }
                .foregroundStyle(palette.fg2)
            }

            ForEach(task.tags, id: \.self) { tag in
                Chip(text: tag, color: .ink)
            }
        }
    }

    private func handleToggle(_ val: Bool) {
        if val {
            // Show the row as done right away — strikethrough, dim,
            // checkbox filled — but hold off on the model mutation so the
            // user sees the completed state land before the row leaves
            // the list. When the delay fires we commit inside withAnimation
            // so the ForEach's .transition handles the slide-out smoothly.
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
