import SwiftUI
import SwiftData

/// Root container for the quiz → plan reveal → paywall → SIWA flow.
///
/// Holds the step index, the shared `OnboardingAnswers`, and handles
/// forward / back / skip transitions with directional slide + spring.
///
/// `onboardingCompleted` is an @AppStorage binding owned by PlootApp.
/// The land screen (24) flips it to true; RootView then swaps in
/// HomeView. This lets the flow survive the `.signedOut → .signedIn`
/// state transition mid-quiz (after SIWA on screen 22) without the
/// user being kicked into HomeView early.
///
/// Returning-user path: tap "Sign in" on welcome → pushes `AuthView`.
/// When SIWA succeeds, PlootApp's .onChange checks remote
/// `profiles.onboarded_at`; if set, onboardingCompleted flips to true
/// and RootView swaps in HomeView automatically.
struct OnboardingFlow: View {
    @Bindable var session: SessionManager
    @Binding var onboardingCompleted: Bool

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
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
            // No back — commitment point.
            PaywallScreen(onBack: nil, onPurchased: goNext)

        case .auth:
            // Post-purchase SIWA. Pushes answers + seeds projects on
            // success, then advances to notifications.
            PostPurchaseAuthScreen(
                session: session,
                answers: answers,
                modelContext: modelContext,
                onComplete: goNext
            )

        case .notifications:
            NotificationsScreen(answers: answers, onComplete: goNext)

        case .land:
            LandScreen(onboardingCompleted: $onboardingCompleted)
        }
    }
}
