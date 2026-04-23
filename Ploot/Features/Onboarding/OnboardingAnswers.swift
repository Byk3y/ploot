import Foundation
import Observation

// Answer enums are string-backed so they encode cleanly into the profiles
// row (migration 0005) without a separate mapping layer.

enum Chronotype: String, CaseIterable, Identifiable, Codable {
    case early       // 5–9am
    case morning     // 9am–noon
    case afternoon   // noon–6pm
    case night       // 6pm onward

    var id: String { rawValue }

    /// Default check-in time we offer for this chronotype. The user can
    /// still override on screen 14.
    var defaultCheckinHour: Int {
        switch self {
        case .early: return 6
        case .morning: return 9
        case .afternoon: return 13
        case .night: return 20
        }
    }
}

enum ReminderStyle: String, CaseIterable, Identifiable, Codable {
    case gentle, firm, none
    var id: String { rawValue }
}

enum PrimaryRole: String, CaseIterable, Identifiable, Codable {
    case student, individualContributor, manager, founder, parent, creative, multiHat, other
    var id: String { rawValue }
}

enum PlanningTime: String, CaseIterable, Identifiable, Codable {
    case nightBefore, morningOf, winging
    var id: String { rawValue }
}

enum CurrentSystem: String, CaseIterable, Identifiable, Codable {
    case appleReminders, notion, postIts, nothing, multiple
    var id: String { rawValue }
}

/// In-memory answer bag held by `OnboardingFlow` for the duration of the
/// quiz. After the user completes SIWA on screen 22 we push this into the
/// `public.profiles` row (see migration 0005) and drop the instance.
///
/// No persistence — if the app is killed mid-flow, the user starts over.
/// That's deliberate; half-finished onboarding answers would be worse than
/// a clean restart.
@Observable
final class OnboardingAnswers {
    // MARK: - Act 1 hook (multi-select)
    var whatBringsYou: Set<String> = []
    var gettingInTheWay: Set<String> = []

    // MARK: - Act 2 personalization
    var primaryRole: PrimaryRole? = nil
    var currentSystem: CurrentSystem? = nil
    var tasksPerDay: Int = 5
    var chronotype: Chronotype? = nil
    var usesProjects: Bool? = nil
    var recurrenceHeavy: Bool? = nil
    var reminderStyle: ReminderStyle = .gentle
    var planningTime: PlanningTime? = nil

    // MARK: - Act 3 commitment
    var dailyGoal: Int = 5
    var checkinTime: Date = OnboardingAnswers.defaultCheckin()
    var trackStreak: Bool = true

    // MARK: - Act 5 plan reveal

    /// Slugs the user has opted into seeding on sign-in. Populated lazily
    /// on screen 19 with every suggestion selected by default — user can
    /// deselect individually. Empty = "start blank."
    var selectedStarterSlugs: Set<String> = []

    /// Starter project suggestions derived from `primaryRole`. Used to
    /// preview on screen 19 and to seed on sign-in (Phase E).
    var suggestedProjects: [StarterProject] {
        StarterProject.suggestions(for: primaryRole)
    }

    /// Projects actually seeded after SIWA — the intersection of the
    /// role-suggested list and the user's per-card selection.
    var projectsToSeed: [StarterProject] {
        suggestedProjects.filter { selectedStarterSlugs.contains($0.slug) }
    }

    private static func defaultCheckin() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 8
        c.minute = 47
        return Calendar.current.date(from: c) ?? Date()
    }
}

// MARK: - Starter projects

/// Project seeded on sign-in (Phase E). Role-driven so the suggestion
/// feels tailored — the whole point of the long quiz is to make the
/// payoff screens earn the investment.
struct StarterProject: Identifiable, Hashable {
    let slug: String
    let name: String
    let emoji: String
    let tileColor: ProjectTileColor

    var id: String { slug }

    static func suggestions(for role: PrimaryRole?) -> [StarterProject] {
        switch role {
        case .student:
            return [
                .init(slug: "classes", name: "Classes", emoji: "📚", tileColor: .sky),
                .init(slug: "assignments", name: "Assignments", emoji: "📝", tileColor: .butter),
                .init(slug: "personal", name: "Personal", emoji: "🎯", tileColor: .primary)
            ]
        case .founder:
            return [
                .init(slug: "shipping", name: "Shipping", emoji: "🚀", tileColor: .primary),
                .init(slug: "business", name: "Business", emoji: "💼", tileColor: .forest),
                .init(slug: "home", name: "Home", emoji: "🏡", tileColor: .sky)
            ]
        case .parent:
            return [
                .init(slug: "home", name: "Home", emoji: "🏡", tileColor: .primary),
                .init(slug: "errands", name: "Errands", emoji: "🛒", tileColor: .butter),
                .init(slug: "kids", name: "Kids", emoji: "👶", tileColor: .sky)
            ]
        case .creative:
            return [
                .init(slug: "projects", name: "Projects", emoji: "🎨", tileColor: .plum),
                .init(slug: "clients", name: "Clients", emoji: "💼", tileColor: .forest),
                .init(slug: "life", name: "Life", emoji: "🌿", tileColor: .primary)
            ]
        case .individualContributor, .manager, .multiHat, .other, .none:
            return [
                .init(slug: "work", name: "Work", emoji: "💼", tileColor: .forest),
                .init(slug: "home", name: "Home", emoji: "🏡", tileColor: .primary),
                .init(slug: "personal", name: "Personal", emoji: "🎯", tileColor: .sky)
            ]
        }
    }
}
