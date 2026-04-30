import SwiftUI
import SwiftData

// Overlays attached to HomeView's tabContent: the voice-capture bubble,
// cancel pill, success toast, and the first-run "hold + to dictate" hint.
// Pulled out of HomeView.swift to keep the main file focused on layout
// and lifecycle.

extension HomeView {

    // MARK: - Voice bubble

    @ViewBuilder
    var voiceBubbleLayer: some View {
        if let phase = voicePhase {
            VoiceCaptureBubble(
                phase: phase,
                transcript: speech.transcript,
                cancelPreview: voiceCancelPreview,
                onCancel: dismissVoice
            )
            .allowsHitTesting(phase != .listening) // listening: gesture goes to FAB
            .transition(bubbleTransition)
            .zIndex(10)
        }
    }

    /// Bubble enter is a friendly scale-from-bottom-right. Exit depends on
    /// context: a cancel exit shrinks to a point while sliding toward the
    /// cancel pill ("popping into the bin"); a normal exit fades.
    var bubbleTransition: AnyTransition {
        let insertion: AnyTransition = .scale(scale: 0.85, anchor: .bottomTrailing)
            .combined(with: .opacity)
        let removal: AnyTransition
        if isCancellingVoice {
            removal = .scale(scale: 0.05, anchor: .bottomLeading)
                .combined(with: .opacity)
                .combined(with: .offset(x: -40, y: 40))
        } else {
            removal = .scale(scale: 0.85, anchor: .bottomTrailing)
                .combined(with: .opacity)
        }
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Cancel pill sits directly to the LEFT of the FAB while listening.
    /// Stays visible briefly after cancel so the user sees the trash
    /// icon bounce as the bubble shrinks into it.
    @ViewBuilder
    var voiceCancelPillLayer: some View {
        if showCancelPill {
            VoiceCancelPill(
                cancelPreview: voiceCancelPreview,
                bounceTrigger: cancelBounceTrigger
            )
            // FAB's outer right edge is at trailing padding 20 + width 60 = 80pt.
            // Put 8pt gap between pill and FAB → pill's right edge at 88pt.
            .padding(.trailing, 88)
            // FAB bottom padding 12 + FAB height 60, pill vertically
            // centered relative to FAB → pill bottom at ~12 + 17 = 29pt.
            .padding(.bottom, 29)
            .transition(.scale(scale: 0.85, anchor: .trailing).combined(with: .opacity))
            .zIndex(9)
        }
    }

    // MARK: - Toast (voice success + correction tap)

    @ViewBuilder
    var toastLayer: some View {
        if let message = voiceToast {
            Button(action: handleToastTap) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.primary)
                    Text(message)
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    if voiceToastTaskId != nil {
                        Text("edit")
                            .font(.geist(size: 12, weight: 600))
                            .foregroundStyle(palette.primary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.md, offset: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(5)
        }
    }

    func handleToastTap() {
        defer {
            withAnimation(Motion.spring) {
                voiceToast = nil
                voiceToastTaskId = nil
            }
        }
        guard let taskId = voiceToastTaskId else { return }
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId && $0.deletedAt == nil }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            editingTask = task
        }
    }

    // MARK: - First-run voice hint

    @ViewBuilder
    var voiceHintLayer: some View {
        if showVoiceHint {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.primary)
                Text("hold + to dictate.")
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg1)
                Button(action: dismissVoiceHint) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.fg3)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(palette.bgElevated))
            .overlay(Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5))
            .stampedShadow(radius: 999, offset: 2)
            .padding(.bottom, 100)
            .padding(.trailing, 90)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .transition(.scale.combined(with: .opacity))
            .zIndex(6)
        }
    }
}
