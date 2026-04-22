import SwiftUI

/// The hero interaction. Springy scale+rotate when checked, stroke-dash check
/// draw, and a success ring that expands and fades. Mirrors the JSX Checkbox
/// in `ui_kits/mobile/Primitives.jsx` as closely as SwiftUI allows.
struct PlootCheckbox: View {
    var checked: Bool
    var priority: Priority = .normal
    var size: CGFloat = 24
    var onToggle: (Bool) -> Void

    @Environment(\.plootPalette) private var palette
    @State private var bouncing: Bool = false
    @State private var ringProgress: CGFloat = 0    // 0 → 1 expansion
    @State private var ringOpacity: Double = 0      // 1 → 0 fade
    @State private var drawProgress: CGFloat = 0    // 0 → 1 check draw

    var body: some View {
        ZStack {
            // Expanding success ring
            Circle()
                .strokeBorder(palette.success, lineWidth: 2)
                .frame(width: size + 12, height: size + 12)
                .scaleEffect(0.6 + 0.6 * ringProgress)
                .opacity(ringOpacity)
                .allowsHitTesting(false)

            // The button itself — filled circle with priority-colored border
            Button {
                toggle()
            } label: {
                Circle()
                    .fill(checked ? palette.success : Color.clear)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                checked ? palette.success : ringColor,
                                lineWidth: 2.5
                            )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        if checked {
                            CheckmarkShape()
                                .trim(from: 0, to: drawProgress)
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                                )
                                .frame(width: size * 0.6, height: size * 0.6)
                        }
                    }
                    .scaleEffect(bouncing ? 1.2 : 1.0)
                    .rotationEffect(.degrees(bouncing ? 8 : 0))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .frame(width: size + 12, height: size + 12)
        .sensoryFeedback(.success, trigger: checked) { old, new in !old && new }
        .onChange(of: checked) { _, new in
            if new {
                animateDraw()
            } else {
                drawProgress = 0
            }
        }
        .task {
            if checked { drawProgress = 1 }
        }
    }

    private var ringColor: Color {
        switch priority {
        case .normal: return palette.borderStrong
        case .medium: return palette.butter500
        case .high:   return palette.plum500
        case .urgent: return palette.primary
        }
    }

    private func toggle() {
        let next = !checked
        if next {
            withAnimation(Motion.spring) {
                bouncing = true
            }
            withAnimation(.easeOut(duration: 0.5)) {
                ringProgress = 1
                ringOpacity = 0
            }
            ringOpacity = 1
            withAnimation(.easeOut(duration: 0.5)) {
                ringOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bouncing = false
                ringProgress = 0
            }
        }
        onToggle(next)
    }

    private func animateDraw() {
        drawProgress = 0
        withAnimation(Motion.spring.delay(0.04)) {
            drawProgress = 1
        }
    }
}

/// The check glyph — matches the `M5 12 L10 17 L19 7` path in the JSX.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        // viewBox is 24×24, path: M5 12 → L10 17 → L19 7
        p.move(to: CGPoint(x: 5 / 24 * w, y: 12 / 24 * h))
        p.addLine(to: CGPoint(x: 10 / 24 * w, y: 17 / 24 * h))
        p.addLine(to: CGPoint(x: 19 / 24 * w, y: 7 / 24 * h))
        return p
    }
}
