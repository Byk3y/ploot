import SwiftUI

/// Unified row primitive for the Settings screen. One component, four
/// trailing variants — never combine. Settings is a *list*, not a stack
/// of cards, so rows lean quiet: no per-row stamped border or shadow,
/// muted icons, single chevron.
///
/// Variants:
/// - `.value(String)` — push-detail row, label + right-aligned value + chevron.
/// - `.toggle(Binding<Bool>)` — label + native iOS toggle. No chevron.
/// - `.action` — label + leading icon, no value. Used for one-shot taps
///   (Restore, Share, Rate). Optional destructive flag tints label red.
/// - `.disclosure` — label + chevron only (no value), for "tap to manage"
///   rows where the value lives elsewhere (Subscription, Notifications).
struct SettingsRow: View {
    enum Trailing {
        case value(String)
        case toggle(Binding<Bool>)
        case disclosure
        case none
    }

    let icon: String?
    let label: String
    let trailing: Trailing
    let destructive: Bool
    let action: (() -> Void)?

    @Environment(\.plootPalette) private var palette

    init(
        icon: String? = nil,
        label: String,
        trailing: Trailing = .disclosure,
        destructive: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.label = label
        self.trailing = trailing
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowBody }
                    .buttonStyle(.plain)
            } else {
                rowBody
            }
        }
    }

    private var rowBody: some View {
        HStack(spacing: Spacing.s3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(destructive ? palette.danger : palette.fg2)
                    .frame(width: 24, alignment: .center)
            }
            Text(label)
                .font(.geist(size: 16, weight: 500))
                .foregroundStyle(destructive ? palette.danger : palette.fg1)
                .lineLimit(1)
            Spacer(minLength: Spacing.s2)
            trailingView
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .value(let v):
            HStack(spacing: 6) {
                Text(v)
                    .font(.geist(size: 14, weight: 500))
                    .foregroundStyle(palette.fg3)
                    .lineLimit(1)
                chevron
            }
        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(palette.primary)
        case .disclosure:
            chevron
        case .none:
            EmptyView()
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.fg3)
    }
}
