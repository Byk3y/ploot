import SwiftUI

/// Root container for the quiz → plan reveal → paywall → SIWA flow.
///
/// Holds the step index, the shared `OnboardingAnswers`, and handles
/// forward / back / skip transitions with directional slide + spring.
///
/// Returning-user path: tap "Sign in" (top trailing) → pushes `AuthView`
/// on the nav stack. When SIWA succeeds `session.state` flips to
/// `.signedIn`, `RootView` swaps in `HomeView`, and this stack is torn
/// down automatically.
struct OnboardingFlow: View {
    @Bindable var session: SessionManager

    @Environment(\.plootPalette) private var palette
    @State private var answers = OnboardingAnswers()
    @State private var step: OnboardingStep = .welcome
    @State private var movingBack: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                palette.bg.ignoresSafeArea()
                screen
                    .id(step)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: movingBack ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: movingBack ? .trailing : .leading).combined(with: .opacity)
                        )
                    )
            }
            .animation(Motion.spring, value: step)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if step == .welcome {
                        NavigationLink {
                            AuthView(session: session)
                        } label: {
                            Text("Sign in")
                                .font(.geist(size: 15, weight: 500))
                                .foregroundStyle(palette.fg2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step machine

    private func goNext() {
        movingBack = false
        advance()
    }

    private func goSkip() {
        movingBack = false
        advance()
    }

    private func goBack() {
        movingBack = true
        retreat()
    }

    private func advance() {
        let next = step.rawValue + 1
        if let s = OnboardingStep(rawValue: next) {
            step = s
        }
    }

    private func retreat() {
        let prev = step.rawValue - 1
        if let s = OnboardingStep(rawValue: prev) {
            step = s
        }
    }

    // MARK: - Screen dispatch

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome:
            WelcomeScreen(onContinue: goNext)

        case .socialProof:
            SocialProofScreen(onBack: goBack, onContinue: goNext)

        case .whatBringsYou:
            WhatBringsYouScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .gettingInTheWay:
            GettingInTheWayScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .role:
            RoleScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .currentSystem:
            CurrentSystemScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .tasksPerDay:
            TasksPerDayScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .chronotype:
            ChronotypeScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .projectsVsList:
            ProjectsVsListScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .recurrence:
            RecurrenceScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .reminderStyle:
            ReminderStyleScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .planningTime:
            PlanningTimeScreen(answers: answers, onBack: goBack, onContinue: goNext, onSkip: goSkip)

        case .dailyGoal:
            DailyGoalScreen(answers: answers, onBack: goBack, onContinue: goNext)

        case .checkinTime:
            CheckinTimeScreen(answers: answers, onBack: goBack, onContinue: goNext)

        case .streak:
            StreakScreen(answers: answers, onBack: goBack, onContinue: goNext)

        case .reviewPrompt:
            ReviewPromptScreen(onBack: goBack, onContinue: goNext)

        case .loading:
            // Auto-advances when the answer stream finishes; no manual back.
            LoadingScreen(answers: answers, onComplete: goNext)

        case .planReveal:
            // No back — the user has just committed and we don't want to
            // give them a "wait let me undo that" exit right before the ask.
            PlanRevealScreen(answers: answers, onContinue: goNext)

        case .starterProjects:
            StarterProjectsScreen(answers: answers, onBack: goBack, onContinue: goNext)

        case .trialTimeline:
            TrialTimelineScreen(onBack: goBack, onContinue: goNext)

        case .paywall:
            // No back from paywall — the point is commitment. The user
            // can still close the app, but within the flow the only way
            // forward is purchase or restore.
            PaywallScreen(onBack: nil, onPurchased: goNext)

        default:
            // Phases D–F build out the remaining screens. Until then,
            // any advance past screen 19 lands here and loops back.
            ComingSoonScreen(step: step, onBack: goBack)
        }
    }
}

// MARK: - Placeholder for un-built phases

private struct ComingSoonScreen: View {
    let step: OnboardingStep
    let onBack: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: step,
            canAdvance: false,
            continueTitle: "Not built yet",
            onBack: onBack,
            onContinue: {},
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                QuestionHeader(
                    eyebrow: "Placeholder",
                    title: "Screen \(step.ordinal) lands here.",
                    subtitle: "Phases C–F will fill this in. Go back to keep testing the flow."
                )
            }
        }
    }
}
