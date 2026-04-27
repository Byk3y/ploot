import SwiftUI
import SwiftData

/// Inline project picker that drops into QuickAddSheet's meta-row picker
/// area when the project pill is tapped. Search field + scrollable list.
/// Selecting a row commits via `onSelect` and the parent auto-closes.
struct InlineProjectList: View {
    var selection: String
    var onSelect: (String) -> Void

    // Filter to live projects only — soft-deleted ones (deletedAt != nil)
    // are tombstones still pending sync propagation, not pickable rows.
    @Query(
        filter: #Predicate<PlootProject> { $0.deletedAt == nil },
        sort: \PlootProject.order
    ) private var projects: [PlootProject]
    @State private var query: String = ""
    @Environment(\.plootPalette) private var palette

    private var allOptions: [PlootProject] {
        [DemoData.inboxProject] + projects
    }

    private var filtered: [PlootProject] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? allOptions : allOptions.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.fg3)
                TextField("Search projects", text: $query)
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.bgSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1.5)
            )

            VStack(spacing: 2) {
                ForEach(filtered) { project in
                    Button {
                        onSelect(project.id)
                    } label: {
                        HStack(spacing: 10) {
                            Text(project.emoji)
                                .font(.system(size: 13))
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(project.tileColor.fill(palette: palette))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(palette.borderInk, lineWidth: 1.5)
                                )
                            Text(project.name)
                                .font(.geist(size: 14, weight: selection == project.id ? 600 : 500))
                                .foregroundStyle(selection == project.id ? palette.clay700 : palette.fg1)
                            Spacer()
                            if selection == project.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(palette.clay700)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(selection == project.id ? palette.clay100 : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: Radius.lg, offset: 2)
    }
}
