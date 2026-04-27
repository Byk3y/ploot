import SwiftUI

/// Floating speech-bubble that rises from the FAB when the user long-
/// presses. Pure presentation: parent owns the SpeechService and provides
/// the transcript + phase. Bubble anchors to the bottom-right, max-width
/// caps at ~320pt, height grows with content up to ~280pt then scrolls
/// internally so the latest words stay visible.
///
/// The bubble explicitly does NOT dim the rest of the screen — task rows
/// behind remain legible. This is a tooltip-scale UI, not a modal
/// takeover.
struct VoiceCaptureBubble: View {
    enum Phase: Equatable {
        case listening
        case thinking
        case permissionDenied
    }

    var phase: Phase
    var transcript: String
    var cancelPreview: Bool
    var onCancel: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.plootTheme) private var theme
    @State private var pulse: Bool = false

    private let maxHeight: CGFloat = 260
    private let maxWidth: CGFloat = 320

    var body: some View {
        bubble
            .frame(maxWidth: maxWidth, alignment: .trailing)
            .frame(maxHeight: maxHeight)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .padding(.bottom, 88)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }

    // Cancel affordance lives OUTSIDE the bubble (see VoiceCancelPill),
    // sitting next to the FAB where the user's thumb is. Keeps the bubble
    // clean for just the transcript.

    // MARK: - Bubble card

    private var bubble: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            header
            transcriptBlock
            footer
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s3)
        .padding(.bottom, Spacing.s3)
        .background(
            // Cocoa's bgElevated only sits ~one stop above bg, so the
            // listening bubble blends into the chocolate canvas. Lift it
            // a few stops with a warm caramel that still belongs to the
            // theme. Light is unchanged.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme == .cocoa ? Color(hex: 0x6A4F38) : palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(cancelPreview ? Color.red.opacity(0.85) : palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: 20, offset: 2, color: cancelPreview ? Color.red.opacity(0.3) : nil)
        .animation(Motion.springFast, value: cancelPreview)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(cancelPreview ? Color.red : Color.red.opacity(0.9))
                .frame(width: 8, height: 8)
                .scaleEffect(pulse && phase == .listening ? 1.25 : 1)
            Text(headerLabel)
                .font(.geist(size: 11, weight: 600))
                .foregroundStyle(palette.fg3)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer(minLength: 0)
        }
    }

    private var headerLabel: String {
        switch phase {
        case .listening: return cancelPreview ? "cancel on release" : "listening"
        case .thinking: return "thinking"
        case .permissionDenied: return "permission needed"
        }
    }

    // MARK: - Transcript

    private var transcriptText: some View {
        Text(transcript)
            .font(.fraunces(size: 18, weight: 500, opsz: 18, soft: 60))
            .tracking(-0.005 * 18)
            .foregroundStyle(palette.fg1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var transcriptBlock: some View {
        switch phase {
        case .listening:
            if transcript.isEmpty {
                // Cocoa's fg3 is a muted brown that drops to ~illegible
                // on the chocolate canvas, so use fg2 there. Light's fg3
                // already reads correctly on cream.
                Text("say it...")
                    .font(.fraunces(size: 18, weight: 500, opsz: 18, soft: 60))
                    .foregroundStyle(theme == .cocoa ? palette.fg2 : palette.fg3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // ViewThatFits picks the first option that fits the
                // available space. Short transcripts → natural-sizing
                // Text (bubble shrinks to hug content). Long transcripts
                // → scroll fallback pinned to the bottom so the most
                // recent words stay visible.
                ViewThatFits(in: .vertical) {
                    transcriptText
                    ScrollView(.vertical, showsIndicators: false) {
                        transcriptText
                    }
                    .defaultScrollAnchor(.bottom)
                }
            }
        case .thinking:
            VStack(alignment: .leading, spacing: Spacing.s1) {
                if !transcript.isEmpty {
                    Text(transcript)
                        .font(.fraunces(size: 16, weight: 500, opsz: 16, soft: 60))
                        .foregroundStyle(palette.fg2)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).tint(palette.fg3)
                    Text("thinking...")
                        .font(.geist(size: 12, weight: 500))
                        .foregroundStyle(palette.fg3)
                }
            }
        case .permissionDenied:
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("voice needs permission.")
                    .font(.fraunces(size: 16, weight: 500, opsz: 16, soft: 60))
                    .foregroundStyle(palette.fg1)
                Text("enable mic + speech in settings → ploot.")
                    .font(.geist(size: 12, weight: 400))
                    .foregroundStyle(palette.fg3)
                HStack(spacing: Spacing.s2) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        onCancel()
                    }
                    .buttonStyle(.ploot(.primary, size: .sm))
                    Button("Got it", action: onCancel)
                        .buttonStyle(.ploot(.ghost, size: .sm))
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        // Listening state has no footer — cancel/save affordance lives as
        // a pill to the left of the FAB, outside the bubble. Thinking and
        // permission-denied states handle their own copy in transcriptBlock.
        EmptyView()
    }
}

#Preview("Listening — empty") {
    VoiceCaptureBubble(phase: .listening, transcript: "", cancelPreview: false, onCancel: {})
        .padding()
        .plootTheme(.light)
}

#Preview("Listening — with text") {
    VoiceCaptureBubble(
        phase: .listening,
        transcript: "buy milk tomorrow at 5",
        cancelPreview: false,
        onCancel: {}
    )
    .padding()
    .plootTheme(.light)
}

#Preview("Cancel preview") {
    VoiceCaptureBubble(
        phase: .listening,
        transcript: "buy milk tomorrow at 5",
        cancelPreview: true,
        onCancel: {}
    )
    .padding()
    .plootTheme(.light)
}

#Preview("Thinking") {
    VoiceCaptureBubble(
        phase: .thinking,
        transcript: "buy milk tomorrow at 5",
        cancelPreview: false,
        onCancel: {}
    )
    .padding()
    .plootTheme(.cocoa)
}
