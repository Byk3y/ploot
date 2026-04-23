import Foundation

/// All screens in the quiz → plan reveal → paywall → SIWA flow.
/// Keeping them in one enum gives us a single source of truth for the
/// progress-bar denominator and the forward/back step machine.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    // Act 1 — hook
    case welcome = 0
    case socialProof
    case whatBringsYou
    case gettingInTheWay

    // Act 2 — personalization
    case role
    case currentSystem
    case tasksPerDay
    case chronotype
    case projectsVsList
    case recurrence
    case reminderStyle
    case planningTime

    // Act 3 — commitment (Phase C)
    case dailyGoal
    case checkinTime
    case streak

    // Act 4 — review (Phase C)
    case reviewPrompt

    // Act 5 — plan reveal (Phase C)
    case loading
    case planReveal
    case starterProjects

    // Act 6 — paywall (Phase D)
    case trialTimeline
    case paywall

    // Act 7 — auth (Phase E)
    case auth
    case notifications

    // Act 8 — land (Phase E)
    case land

    var id: Int { rawValue }

    /// True for screens that should hide the progress bar (intro only).
    var hidesProgress: Bool {
        self == .welcome || self == .loading || self == .planReveal || self == .land
    }

    /// True if the user can tap "Skip" to bypass the question.
    /// Personalization screens allow skip; commitment and paywall don't.
    var allowsSkip: Bool {
        switch self {
        case .whatBringsYou, .gettingInTheWay,
             .role, .currentSystem, .tasksPerDay, .chronotype,
             .projectsVsList, .recurrence, .reminderStyle, .planningTime:
            return true
        default:
            return false
        }
    }

    /// 1-indexed position for the progress bar.
    var ordinal: Int { rawValue + 1 }

    static var total: Int { OnboardingStep.allCases.count }
}
