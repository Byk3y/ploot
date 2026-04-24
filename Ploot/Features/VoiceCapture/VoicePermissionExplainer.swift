import SwiftUI

/// First-run voice permission primer. Shown before the iOS system dialog
/// so we can explain what we're about to ask for and why — doubles the
/// grant rate vs. jumping straight to the OS prompt per Apple HIG.
///
/// Stored-once behavior: a `@AppStorage` flag in HomeView means this
/// sheet only appears on the very first voice attempt. If the user taps
/// "not now", we don't hammer them on every subsequent long-press —
/// they'll get the standard OS dialog only if they try again.
struct VoicePermissionExplainer: View {
    var onEnable: () -> Void
    var onDismiss: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: Spacing.s5) {
            Spacer().frame(height: Spacing.s4)

            // Icon cluster
            ZStack {
                Circle()
                    .fill(palette.primary.opacity(0.18))
                    .frame(width: 84, height: 84)
                Image(systemName: "waveform")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }

            VStack(spacing: Spacing.s2) {
                Text("mind if we listen?")
                    .font(.fraunces(size: 28, weight: 600, opsz: 28, soft: 60))
                    .tracking(-0.015 * 28)
                    .foregroundStyle(palette.fg1)
                    .multilineTextAlignment(.center)

                Text("hold the + button and say what's next — we'll turn it into a task. nothing gets recorded or uploaded.")
                    .font(.geist(size: 15, weight: 400))
                    .foregroundStyle(palette.fg2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.s4)
            }

            VStack(alignment: .leading, spacing: Spacing.s3) {
                bullet(icon: "lock.shield.fill", title: "on-device only", body: "transcription happens on your phone. we don't send audio anywhere.")
                bullet(icon: "hand.raised.fill", title: "only when you hold", body: "the mic is off every other moment — no background listening.")
                bullet(icon: "mic.slash.fill", title: "revocable anytime", body: "disable mic + speech in settings → ploot and voice input switches off.")
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)

            Spacer()

            VStack(spacing: Spacing.s2) {
                Button(action: onEnable) {
                    Text("enable voice")
                        .font(.geist(size: 16, weight: 700))
                        .foregroundStyle(palette.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(palette.primary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(palette.borderInk, lineWidth: 2)
                        )
                        .stampedShadow(radius: Radius.md, offset: 3)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("not now")
                        .font(.geist(size: 14, weight: 500))
                        .foregroundStyle(palette.fg3)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s4)
        }
        .background(palette.bg.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: false)
    }

    private func bullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Text(body)
                    .font(.geist(size: 12, weight: 400))
                    .foregroundStyle(palette.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    VoicePermissionExplainer(onEnable: {}, onDismiss: {})
        .plootTheme(.light)
}
