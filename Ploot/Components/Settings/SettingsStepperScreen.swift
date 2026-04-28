import SwiftUI

/// Generic numeric picker for settings like Daily Goal (1–10) and
/// Clarifying Questions (0–5). Big centered number + Geist label, with
/// minus/plus buttons that respect bounds and feel bouncy.
struct SettingsStepperScreen: View {
    let title: String
    let unitLabel: String
    let footer: String?
    let range: ClosedRange<Int>
    @Binding var value: Int
    var onChange: ((Int) -> Void)? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenFrame(
            title: title,
            leading: { HeaderButton(systemImage: "arrow.left") { dismiss() } }
        ) {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                stepperCard
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
                if let footer {
                    Text(footer)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .padding(.horizontal, Spacing.s4 + Spacing.s4)
                        .padding(.top, Spacing.s1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var stepperCard: some View {
        HStack(spacing: Spacing.s4) {
            Spacer(minLength: 0)
            stepperButton(systemImage: "minus", enabled: value > range.lowerBound) {
                bump(-1)
            }
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.fraunces(size: 56, weight: 600, opsz: 72, soft: 40))
                    .foregroundStyle(palette.fg1)
                    .contentTransition(.numericText(value: Double(value)))
                    .frame(minWidth: 80)
                    .animation(Motion.spring, value: value)
                Text(unitLabel)
                    .font(.jetBrainsMono(size: 11, weight: 600))
                    .tracking(11 * 0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.fg3)
            }
            stepperButton(systemImage: "plus", enabled: value < range.upperBound) {
                bump(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.s5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 0.6)
        )
    }

    private func bump(_ delta: Int) {
        let next = max(range.lowerBound, min(range.upperBound, value + delta))
        guard next != value else { return }
        withAnimation(Motion.spring) { value = next }
        onChange?(next)
    }

    private func stepperButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? palette.fg1 : palette.fg3)
                .frame(width: 48, height: 48)
                .background(Circle().fill(palette.bgSunken))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .plootHaptic(.impact(weight: .light), trigger: value)
    }
}
