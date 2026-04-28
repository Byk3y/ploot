import SwiftUI

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
            .plootHaptic(.selection, trigger: value)
        }
    }
}
