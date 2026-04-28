import SwiftUI

/// A single tappable answer row — stamped card with optional leading
/// emoji, title, and subtitle. Used by both single-select and multi-
/// select onboarding screens.
struct ChoiceCard: View {
    let emoji: String?
    let title: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.s3) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geist(size: 16, weight: 600))
                        .foregroundStyle(selected ? palette.onPrimary : palette.fg1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.geist(size: 13, weight: 400))
                            .foregroundStyle(selected ? palette.onPrimary.opacity(0.85) : palette.fg3)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.onPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(selected ? palette.primary : palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: 2)
            )
            .stampedShadow(radius: Radius.md, offset: 2)
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: selected)
        .animation(Motion.springFast, value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(selected ? "Selected. Double-tap to deselect." : "Double-tap to select."))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var accessibilityLabel: String {
        [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    }
}
