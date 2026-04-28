import SwiftUI

/// The "✨ break this down for me" entry point. Appears at the top of an
/// empty project's detail screen. Dashed outline + muted surface to read
/// as an offer rather than a committed task — tap to invoke the AI
/// breakdown sheet.
struct BreakdownGhostRow: View {
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var pressed: Bool = false
    @State private var sparkle: Int = 0

    var body: some View {
        Button(action: {
            sparkle &+= 1
            onTap()
        }) {
            HStack(spacing: Spacing.s3) {
                Text("✨")
                    .font(.system(size: 22))
                    .symbolEffect(.bounce, value: sparkle)
                    .scaleEffect(pressed ? 0.9 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("break this down for me")
                        .font(.geist(size: 15, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text("ai turns a project into a few clear steps.")
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.fg2)
                    .offset(x: pressed ? 3 : 0)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(palette.bgElevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(
                        palette.border,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        withAnimation(Motion.springFast) { pressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(Motion.springFast) { pressed = false }
                }
        )
        .plootHaptic(.impact(weight: .light), trigger: sparkle)
    }
}

#Preview("Light") {
    BreakdownGhostRow(onTap: {})
        .padding()
        .plootTheme(.light)
}

#Preview("Cocoa") {
    BreakdownGhostRow(onTap: {})
        .padding()
        .plootTheme(.cocoa)
}
