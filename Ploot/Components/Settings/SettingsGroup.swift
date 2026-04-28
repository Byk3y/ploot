import SwiftUI

/// A grouped block of `SettingsRow`s. Flat fill (`bgElevated`), no
/// stamped border, no shadow — settings is a utility surface, not a hero
/// stack. Rows inside the group are separated by a hairline divider that
/// indents past the leading icon, matching the iOS Settings convention.
///
/// Optional `header` prints a small mono uppercase label above the group
/// (the "wayfinding" handled by typography, not chrome). Optional
/// `footer` prints a quiet hint below — that's where copy like
/// "Streaks count once you hit your goal." lives, not inside a row.
struct SettingsGroup<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header {
                Text(header)
                    .font(.jetBrainsMono(size: 11, weight: 600))
                    .tracking(11 * 0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.fg3)
                    .padding(.leading, Spacing.s4)
            }

            VStack(spacing: 0) {
                _VariadicView.Tree(SettingsRowLayout()) {
                    content()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 0.6)
            )

            if let footer {
                Text(footer)
                    .font(.geist(size: 12, weight: 400))
                    .foregroundStyle(palette.fg3)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Walks the group's children and inserts an indented hairline divider
/// between each row. Same idiom UIKit's grouped UITableView uses.
private struct SettingsRowLayout: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let count = children.count
        return VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                child
                if index < count - 1 {
                    SettingsRowDivider()
                }
            }
        }
    }
}

private struct SettingsRowDivider: View {
    @Environment(\.plootPalette) private var palette
    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 0.6)
            // Indent matches the row's icon column width (24pt icon + 16pt
            // leading padding + 12pt icon-to-label spacing).
            .padding(.leading, Spacing.s4 + 24 + Spacing.s3)
    }
}
