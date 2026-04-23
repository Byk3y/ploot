import SwiftUI

// MARK: - Choice card

/// A single tappable answer row — stamped card with optional leading emoji,
/// title, and subtitle. Used by both single-select and multi-select screens.
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
        .sensoryFeedback(.selection, trigger: selected)
        .animation(Motion.springFast, value: selected)
    }
}

// MARK: - Intensity slider

/// Big visual slider used for tasks-per-day and daily-goal screens.
/// Value bubble floats above the thumb, track is stamped.
struct IntensitySlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let caption: (Int) -> String

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: Spacing.s6) {
            // Big number display
            VStack(spacing: Spacing.s2) {
                Text("\(value)")
                    .font(.fraunces(size: 96, weight: 600, opsz: 144, soft: 40))
                    .foregroundStyle(palette.fg1)
                Text(caption(value))
                    .font(.geist(size: 14, weight: 500))
                    .foregroundStyle(palette.fg3)
            }

            // Slider
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(palette.primary)
            .sensoryFeedback(.selection, trigger: value)
        }
    }
}

// MARK: - Time picker card

struct TimePickerCard: View {
    @Binding var time: Date

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: Spacing.s3) {
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.s2)
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
