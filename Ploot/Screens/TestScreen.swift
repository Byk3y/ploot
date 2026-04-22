import SwiftUI

/// Phase-1 visual verification harness. Renders the tokens in both themes
/// side-by-side (picker at top) so you can eyeball the stamped shadow, the
/// Fraunces display, the clay primary button, and a chip against the cream
/// and cocoa canvases without opening Xcode's preview.
struct TestScreen: View {
    @State private var theme: PlootTheme = .light

    var body: some View {
        ZStack {
            theme.palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    themePicker
                    header
                    bodyCopy
                    buttonRow
                    chipRow
                    demoCard
                    stampedShadowLegend
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s12)
            }
        }
        .plootTheme(theme)
        .animation(Motion.spring, value: theme)
    }

    // MARK: - Sections

    private var themePicker: some View {
        HStack(spacing: Spacing.s2) {
            Text("ploot · phase 1")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)
            Spacer()
            HStack(spacing: 0) {
                ForEach(PlootTheme.allCases) { t in
                    Button {
                        theme = t
                    } label: {
                        Text(t.rawValue)
                            .font(.geist(size: 12, weight: 600))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(theme == t ? theme.palette.onPrimary : theme.palette.fg2)
                            .background(
                                Capsule().fill(theme == t ? theme.palette.primary : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(theme.palette.bgSunken)
            )
            .overlay(
                Capsule().strokeBorder(theme.palette.border, lineWidth: 1)
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("TUESDAY, APR 21")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)

            Text("Crush today.")
                .textStyle(TextStyles.display)
                .foregroundStyle(theme.palette.fg1)

            Text("— the cream canvas")
                .textStyle(TextStyles.serifItalic(size: 22))
                .foregroundStyle(theme.palette.fg3)
        }
    }

    private var bodyCopy: some View {
        Text("Ploot is warm, playful, and a little absurd. Clay-orange on cream. Fraunces serif meets Geist sans. Dark hairlines, stamped shadows, bouncy springs. Nothing on the list? Suspicious.")
            .textStyle(TextStyles.body)
            .foregroundStyle(theme.palette.fg2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var buttonRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("buttons")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)

            HStack(spacing: Spacing.s3) {
                Button("Add task") {}
                    .buttonStyle(.plootPrimary)

                Button("Skip") {}
                    .buttonStyle(.plootSecondary)

                Button("Cancel") {}
                    .buttonStyle(.plootGhost)
            }
        }
    }

    private var chipRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("chips")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)

            HStack(spacing: Spacing.s2) {
                Chip(text: "deep work", color: .ink)
                Chip(text: "Today", color: .clay, leadingEmoji: "📅")
                Chip(text: "Home", color: .forest, leadingEmoji: "✓")
                Chip(text: "Urgent", color: .plum, leadingEmoji: "🔥")
            }
        }
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("stamped card")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)

            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack {
                    Text("7 day streak")
                        .textStyle(TextStyles.h3)
                        .foregroundStyle(theme.palette.fg1)
                    Spacer()
                    Text("🔥")
                        .font(.system(size: 28))
                }

                Text("don't break it")
                    .textStyle(TextStyles.body)
                    .foregroundStyle(theme.palette.fg2)

                HStack(spacing: Spacing.s2) {
                    Chip(text: "3 of 6 crushed", color: .butter)
                    Chip(text: "keep going", color: .ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(radius: Radius.lg, padding: Spacing.s5)
        }
    }

    private var stampedShadowLegend: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("stamped shadow · radii")
                .eyebrow()
                .foregroundStyle(theme.palette.fg3)

            HStack(spacing: Spacing.s3) {
                ForEach(
                    [("xs", Radius.xs), ("sm", Radius.sm), ("md", Radius.md), ("lg", Radius.lg), ("xl", Radius.xl)],
                    id: \.0
                ) { label, radius in
                    VStack(spacing: Spacing.s1) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(theme.palette.bgElevated)
                            .frame(width: 52, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(theme.palette.borderInk, lineWidth: 2)
                            )
                            .stampedShadow(radius: radius, offset: 2)

                        Text(label)
                            .font(.jetBrainsMono(size: 10, weight: 600))
                            .foregroundStyle(theme.palette.fg2)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    TestScreen()
        .plootTheme(.light)
        .task { PlootFonts.register() }
}

#Preview("Cocoa") {
    TestScreen()
        .plootTheme(.cocoa)
        .task { PlootFonts.register() }
}
