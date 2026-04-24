import SwiftUI

/// Claude-style clarifier. Renders the model's single question plus 2–4
/// tappable choice chips and a "something else..." escape that expands
/// inline into a text field. Tapping any choice (or submitting the
/// custom field) fires `onAnswer` with that string.
///
/// The card is purely presentational — the parent BreakdownSheet owns the
/// state machine and fires the next edge function call based on the answer.
struct BreakdownQuestionCard: View {
    let question: String
    let choices: [String]
    let allowCustom: Bool
    var onAnswer: (String) -> Void

    @Environment(\.plootPalette) private var palette
    @State private var customExpanded: Bool = false
    @State private var customText: String = ""
    @State private var picked: String? = nil
    @FocusState private var customFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            questionText
            choiceChips
        }
        .cardStyle(radius: Radius.lg, padding: Spacing.s4)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .top)),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }

    // MARK: - Question

    private var questionText: some View {
        HStack(alignment: .top, spacing: Spacing.s2) {
            Text("✦")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.primary)
                .offset(y: 2)

            Text(question)
                .font(.fraunces(size: 20, weight: 500, opsz: 20, soft: 60))
                .tracking(-0.01 * 20)
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Choices

    private var choiceChips: some View {
        BreakdownFlowLayout(spacing: Spacing.s2, lineSpacing: Spacing.s2) {
            ForEach(choices, id: \.self) { choice in
                choiceChip(choice)
            }
            if allowCustom {
                if customExpanded {
                    customField
                } else {
                    customChip
                }
            }
        }
    }

    private func choiceChip(_ choice: String) -> some View {
        let isPicked = picked == choice
        return Button {
            guard picked == nil else { return }
            withAnimation(Motion.springFast) {
                picked = choice
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onAnswer(choice)
            }
        } label: {
            Text(choice)
                .font(.geist(size: 14, weight: 600))
                .foregroundStyle(isPicked ? palette.fgInverse : palette.fg1)
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isPicked ? palette.borderInk : palette.bgElevated)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .scaleEffect(isPicked ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
        .opacity(picked == nil || isPicked ? 1 : 0.35)
        .sensoryFeedback(.selection, trigger: isPicked)
    }

    private var customChip: some View {
        Button {
            withAnimation(Motion.spring) {
                customExpanded = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                customFocused = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("something else")
                    .font(.geist(size: 14, weight: 600))
            }
            .foregroundStyle(palette.fg2)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.bg)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        palette.border,
                        style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
        .opacity(picked == nil ? 1 : 0.35)
    }

    private var customField: some View {
        HStack(spacing: Spacing.s2) {
            TextField("type it", text: $customText)
                .font(.geist(size: 14, weight: 500))
                .foregroundStyle(palette.fg1)
                .focused($customFocused)
                .submitLabel(.go)
                .onSubmit(submitCustom)
                .frame(minWidth: 120)

            Button(action: submitCustom) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.fgInverse)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(
                        customText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? palette.fg3
                        : palette.borderInk
                    ))
            }
            .buttonStyle(.plain)
            .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.leading, Spacing.s3)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
    }

    private func submitCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, picked == nil else { return }
        withAnimation(Motion.springFast) {
            picked = trimmed
        }
        customFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onAnswer(trimmed)
        }
    }
}

/// Light-weight flow layout that wraps chips onto the next line when the
/// container is too narrow. SwiftUI's ViewThatFits / HStack can't do this
/// generically, so the AI-breakdown card brings its own.
private struct BreakdownFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var lineW: CGFloat = 0
        var totalH: CGFloat = 0
        var lineH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if lineW + size.width > maxW, lineW > 0 {
                totalH += lineH + lineSpacing
                lineW = 0
                lineH = 0
            }
            lineW += size.width + spacing
            lineH = max(lineH, size.height)
        }
        totalH += lineH
        return CGSize(width: maxW.isFinite ? maxW : lineW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineH + lineSpacing
                lineH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
    }
}

#Preview("Question") {
    BreakdownQuestionCard(
        question: "DIY or hire a pro?",
        choices: ["DIY", "hire someone", "not sure"],
        allowCustom: true,
        onAnswer: { _ in }
    )
    .padding()
    .plootTheme(.light)
}
