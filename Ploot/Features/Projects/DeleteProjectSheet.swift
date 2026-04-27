import SwiftUI

/// Branded confirmation sheet for project deletion. Replaces the system
/// `confirmationDialog` so the choice surface matches Ploot's stamped/cream
/// look and so we don't inherit the popover anchor from a triggering
/// `.contextMenu` (which makes the system dialog render as a tail-anchored
/// popover instead of a centered action sheet on iPhone).
///
/// The sheet exposes two destructive paths when the project has tasks:
///   * "keep tasks" — null out their `projectId` (mirrors Supabase
///     `ON DELETE SET NULL`).
///   * "delete tasks too" — soft-delete each task so reminders cancel and
///     the tombstones propagate to Supabase.
/// When the project is empty, only a single "Delete" appears.
struct DeleteProjectSheet: View {
    let project: PlootProject
    let taskCount: Int
    var onKeepTasks: () -> Void
    var onCascade: () -> Void
    var onCancel: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.plootTheme) private var theme

    /// Light's `danger` (plum500) reads fine on cream, but on cocoa it
    /// dims into the chocolate canvas. Brighten to a saturated pink that
    /// still belongs to the plum family.
    private var dangerColor: Color {
        theme == .cocoa ? Color(hex: 0xFF5C9E) : palette.danger
    }

    var body: some View {
        VStack(spacing: Spacing.s5) {
            header
            choices
            cancelButton
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s4)
        .background(palette.bg.ignoresSafeArea())
    }

    private var plural: String { taskCount == 1 ? "" : "s" }

    private var header: some View {
        VStack(spacing: Spacing.s3) {
            Text(project.emoji)
                .font(.system(size: 36))
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(project.tileColor.fill(palette: palette))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: 18, offset: 2)

            Text("Delete this project?")
                .font(.fraunces(size: 24, weight: 600, opsz: 24, soft: 60))
                .foregroundStyle(palette.fg1)
                .multilineTextAlignment(.center)

            Text(subtitleText)
                .font(.geist(size: 14, weight: 400))
                .foregroundStyle(palette.fg3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s2)
        }
    }

    private var subtitleText: String {
        if taskCount == 0 {
            return "Empty project. Just cleanup."
        }
        return "Pick what to do with the \(taskCount) task\(plural) inside."
    }

    @ViewBuilder
    private var choices: some View {
        VStack(spacing: Spacing.s3) {
            if taskCount == 0 {
                actionButton(
                    title: "Delete project",
                    detail: nil,
                    action: onKeepTasks
                )
            } else {
                actionButton(
                    title: "Delete project, keep \(taskCount) task\(plural)",
                    detail: "Tasks stay, but lose their project label.",
                    action: onKeepTasks
                )
                actionButton(
                    title: "Delete project and \(taskCount) task\(plural)",
                    detail: "Everything inside is gone too.",
                    action: onCascade
                )
            }
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.geist(size: 16, weight: 600))
                .foregroundStyle(palette.fg2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        detail: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geist(size: 15, weight: 700))
                        .foregroundStyle(dangerColor)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.geist(size: 12, weight: 400))
                            .foregroundStyle(palette.fg3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.danger)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: 2)
            )
            .stampedShadow(radius: Radius.md, offset: 2)
        }
        .buttonStyle(.plain)
    }
}
