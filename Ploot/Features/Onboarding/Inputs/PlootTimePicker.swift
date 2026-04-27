import SwiftUI

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
    @State private var hourSelection: Int?
    @State private var minuteSelection: Int?
    @State private var isAM: Bool

    private let itemWidth: CGFloat = 68

    init(time: Binding<Date>) {
        self._time = time
        // Seed the scrub positions from the binding value at construction
        // time — if we deferred this to .onAppear, the first frame would
        // render at our defaults (8:47 AM) and visibly snap to the real
        // value on appearance.
        let comp = Calendar.current.dateComponents([.hour, .minute], from: time.wrappedValue)
        let h24 = comp.hour ?? 8
        let m = comp.minute ?? 47
        let am = h24 < 12
        let h12: Int
        if h24 == 0 { h12 = 12 }
        else if h24 > 12 { h12 = h24 - 12 }
        else { h12 = h24 }
        self._hourSelection = State(initialValue: h12)
        self._minuteSelection = State(initialValue: m)
        self._isAM = State(initialValue: am)
    }

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
