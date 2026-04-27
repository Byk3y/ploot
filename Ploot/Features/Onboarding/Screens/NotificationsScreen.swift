import SwiftUI
import UserNotifications

// MARK: - Screen 23 · Notifications

struct NotificationsScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onComplete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var isRequesting: Bool = false

    var body: some View {
        OnboardingFrame(
            step: .notifications,
            canAdvance: true,
            continueTitle: isRequesting ? "…" : "Turn on nudges",
            onBack: nil,
            onContinue: { Task { await requestAndAdvance() } },
            onSkip: { scheduleOnlyThenAdvance() }
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Last thing",
                    title: "Can we ping you at \(formatTime(answers.checkinTime))?",
                    subtitle: reminderCopy
                )

                // Illustration card
                VStack(spacing: Spacing.s3) {
                    Text("🔔")
                        .font(.system(size: 56))
                        .opacity(answers.reminderStyle == .none ? 0.3 : 1)
                    Text(answers.reminderStyle == .none ? "You chose no reminders — we'll stay quiet." : "One nudge per day. No five-minute spam.")
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.s6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.lg, offset: 2)

                Spacer(minLength: 0)
            }
        }
    }

    private var reminderCopy: String {
        switch answers.reminderStyle {
        case .gentle: return "Gentle nudge — easy to ignore if you're in flow."
        case .firm: return "Firm ping — you asked, we'll mean it."
        case .none: return "We'll skip the ping. You can turn it on in Settings later."
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }

    private func requestAndAdvance() async {
        isRequesting = true
        defer { isRequesting = false }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await OnboardingNotifications.scheduleTrialReminder()
                ReminderService.shared.scheduleDailyCheckin()
            }
        } catch {
            #if DEBUG
            print("[Onboarding] Notification auth failed: \(error)")
            #endif
        }
        onComplete()
    }

    private func scheduleOnlyThenAdvance() {
        Task {
            await OnboardingNotifications.scheduleTrialReminder()
            // Even if the user skipped the permission prompt, schedule
            // the daily check-in — it's harmless when permission was
            // never granted (iOS silently no-ops) and will start firing
            // as soon as they grant permission later from Settings.
            ReminderService.shared.scheduleDailyCheckin()
            onComplete()
        }
    }
}

// MARK: - Notification scheduling

enum OnboardingNotifications {
    /// Schedule the Day-5 trial-ending reminder. Safe to call even if
    /// permissions weren't granted — UNNotificationCenter silently
    /// no-ops the request.
    static func scheduleTrialReminder() async {
        let center = UNUserNotificationCenter.current()
        // Clear any prior Day-5 schedules so re-runs don't stack up.
        center.removePendingNotificationRequests(withIdentifiers: ["ploot.trial.day5"])

        let content = UNMutableNotificationContent()
        content.title = "Your trial ends in 2 days"
        content.body = "Your plan, your streak, your projects — keep them going with Ploot Pro."
        content.sound = .default

        // 5 days from now. For local testing, override PLOOT_TRIAL_DEBUG
        // at build time to fire at 30s.
        let trigger: UNNotificationTrigger
        #if DEBUG
        if ProcessInfo.processInfo.environment["PLOOT_TRIAL_DEBUG"] == "1" {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24 * 5, repeats: false)
        }
        #else
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24 * 5, repeats: false)
        #endif

        let request = UNNotificationRequest(
            identifier: "ploot.trial.day5",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
