import SwiftUI

enum PlootTab: String, CaseIterable, Hashable {
    case today, projects, calendar, done

    var label: String {
        switch self {
        case .today:    return "Today"
        case .projects: return "Projects"
        case .calendar: return "Calendar"
        case .done:     return "Done"
        }
    }

    /// SF Symbols picked to match the Lucide icons the web kit uses.
    /// Returns (outlined, filled) — some symbols (calendar) have no `.fill`
    /// variant, so we fall back to a filled analogue by name.
    var icon: (inactive: String, active: String) {
        switch self {
        case .today:    return ("sun.max", "sun.max.fill")
        case .projects: return ("folder", "folder.fill")
        case .calendar: return ("calendar", "calendar.circle.fill")
        case .done:     return ("checkmark.circle", "checkmark.circle.fill")
        }
    }
}

struct TabBar: View {
    @Binding var current: PlootTab

    @Environment(\.plootPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlootTab.allCases, id: \.self) { tab in
                TabItem(tab: tab, active: current == tab) {
                    withAnimation(Motion.spring) {
                        current = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.s2)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s1)
        .background(palette.bgElevated)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.borderInk)
                .frame(height: 2)
        }
    }
}

private struct TabItem: View {
    let tab: PlootTab
    let active: Bool
    let onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: active ? tab.icon.active : tab.icon.inactive)
                    .font(.system(size: 22, weight: active ? .bold : .medium))
                    .scaleEffect(active ? 1.1 : 1.0)
                    .offset(y: active ? -1 : 0)
                    .animation(Motion.spring, value: active)

                Text(tab.label)
                    .font(.geist(size: 11, weight: active ? 700 : 500))
            }
            .foregroundStyle(active ? palette.primary : palette.fg3)
            .padding(.vertical, Spacing.s2)
            .padding(.horizontal, Spacing.s1)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
    }
}
