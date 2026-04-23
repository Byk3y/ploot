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

// MARK: - Premium time picker

/// Custom time picker built for the onboarding aesthetic. Big serif
/// display on top, AM/PM segmented toggle, then two horizontal
/// scrub-to-select strips: hours (1–12) and minutes (0–59 in 1-min
/// steps). The focused item in each strip scales up and neighbors
/// fade out — the "zoom into center" feel. Haptic selection tick on
/// every snap.
///
/// Much more on-brand than `DatePicker(.wheel)`, which also happened
/// to render as an empty capsule without an explicit intrinsic height.
struct PlootTimePicker: View {
    @Binding var time: Date

    @Environment(\.plootPalette) private var palette
    @State private var hourSelection: Int? = nil
    @State private var minuteSelection: Int? = nil
    @State private var isAM: Bool = true

    private let itemWidth: CGFloat = 68

    var body: some View {
        VStack(spacing: Spacing.s5) {
            display
            ampmToggle
            VStack(spacing: Spacing.s3) {
                scrubLabel("HOUR")
                scrubStrip(
                    values: Array(1...12),
                    selection: $hourSelection,
                    format: { "\($0)" }
                )
                scrubLabel("MINUTE")
                scrubStrip(
                    values: Array(0...59),
                    selection: $minuteSelection,
                    format: { String(format: "%02d", $0) }
                )
            }
        }
        .padding(.vertical, Spacing.s5)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: Radius.xl, offset: 2)
        .onAppear { loadFromBinding() }
        .onChange(of: hourSelection) { _, _ in writeToBinding() }
        .onChange(of: minuteSelection) { _, _ in writeToBinding() }
        .onChange(of: isAM) { _, _ in writeToBinding() }
    }

    // MARK: Display

    private var display: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(hourSelection ?? 8)")
                .font(.fraunces(size: 72, weight: 600, opsz: 144, soft: 40))
                .foregroundStyle(palette.fg1)
                .contentTransition(.numericText())
                .animation(Motion.spring, value: hourSelection)
            Text(":")
                .font(.fraunces(size: 72, weight: 400, opsz: 144, soft: 40))
                .foregroundStyle(palette.fg3)
            Text(String(format: "%02d", minuteSelection ?? 47))
                .font(.fraunces(size: 72, weight: 600, opsz: 144, soft: 40))
                .foregroundStyle(palette.fg1)
                .contentTransition(.numericText())
                .animation(Motion.spring, value: minuteSelection)
            Text(isAM ? "am" : "pm")
                .font(.fraunces(size: 24, weight: 500, opsz: 72, soft: 50, italic: true))
                .foregroundStyle(palette.fgBrand)
                .padding(.leading, Spacing.s2)
        }
        .tracking(-0.02 * 72)
    }

    // MARK: AM/PM toggle

    private var ampmToggle: some View {
        HStack(spacing: 4) {
            ampmChip(label: "AM", active: isAM) { isAM = true }
            ampmChip(label: "PM", active: !isAM) { isAM = false }
        }
        .padding(4)
        .background(
            Capsule().fill(palette.bgSunken)
        )
        .overlay(
            Capsule().strokeBorder(palette.border, lineWidth: 1.5)
        )
    }

    private func ampmChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.geist(size: 13, weight: 700))
                .foregroundStyle(active ? palette.onPrimary : palette.fg3)
                .frame(width: 56, height: 32)
                .background(
                    Capsule().fill(active ? palette.primary : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(active ? palette.borderInk : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
        .animation(Motion.springFast, value: active)
    }

    // MARK: Scrub strip

    private func scrubLabel(_ text: String) -> some View {
        Text(text)
            .font(.jetBrainsMono(size: 10, weight: 500))
            .tracking(11 * 0.08)
            .foregroundStyle(palette.fg3)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func scrubStrip(
        values: [Int],
        selection: Binding<Int?>,
        format: @escaping (Int) -> String
    ) -> some View {
        GeometryReader { outer in
            let sidePad = max(0, (outer.size.width - itemWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(format(value))
                            .font(.fraunces(size: 30, weight: 600, opsz: 100, soft: 40))
                            .foregroundStyle(palette.fg1)
                            .frame(width: itemWidth, height: 56)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(1.0 - abs(phase.value) * 0.35)
                                    .opacity(1.0 - abs(phase.value) * 0.6)
                            }
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: selection)
            .safeAreaPadding(.horizontal, sidePad)
            .sensoryFeedback(.selection, trigger: selection.wrappedValue)
            .overlay(centerIndicator, alignment: .center)
            .overlay(edgeFade)
        }
        .frame(height: 56)
    }

    private var centerIndicator: some View {
        // Subtle clay-colored underline beneath the centered item.
        Rectangle()
            .fill(palette.primary)
            .frame(width: itemWidth - 24, height: 3)
            .offset(y: 22)
            .allowsHitTesting(false)
    }

    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [palette.bgElevated, palette.bgElevated.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 56)
            Spacer()
            LinearGradient(
                colors: [palette.bgElevated.opacity(0), palette.bgElevated],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 56)
        }
        .allowsHitTesting(false)
    }

    // MARK: Binding sync

    private func loadFromBinding() {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: time)
        let h24 = comp.hour ?? 8
        let m = comp.minute ?? 47
        isAM = h24 < 12
        let h12: Int
        if h24 == 0 { h12 = 12 }
        else if h24 > 12 { h12 = h24 - 12 }
        else { h12 = h24 }
        hourSelection = h12
        minuteSelection = m
    }

    private func writeToBinding() {
        guard let h = hourSelection, let m = minuteSelection else { return }
        let h24: Int
        if isAM {
            h24 = (h == 12) ? 0 : h
        } else {
            h24 = (h == 12) ? 12 : h + 12
        }
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: time)
        comp.hour = h24
        comp.minute = m
        if let d = Calendar.current.date(from: comp) { time = d }
    }
}
