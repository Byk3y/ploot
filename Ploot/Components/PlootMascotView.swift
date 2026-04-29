import SwiftUI

/// Picks the right Ploot mascot pose for a given streak state and
/// renders it from the Mascot/ asset namespace. Swap-in for the old
/// `FireLottieView` — the API matches (`isDimmed`, `frame(...)`) so
/// existing call sites keep working.
///
/// Pose mapping:
///   - `.onFire`  → PlootPointing (paw forward, sprout up, "let's go")
///   - `.atRisk`  → PlootPleading (paws clasped, single tear, "please")
///   - `.cold`    → PlootSleeping (curled with Z's, "no streak yet")
///
/// The `isDimmed` flag is preserved for callers that care about a
/// muted visual on at-risk / cold states. With the mascot, the *pose*
/// already communicates state — but a small opacity drop on cold/at-risk
/// keeps continuity with the previous fire-based UI.
struct PlootMascotView: View {
    enum Pose {
        case onFire   // streak alive, secured today
        case atRisk   // streak alive, today not yet secured
        case cold     // no streak

        /// Free-form pose names — used directly for one-off placements
        /// like onboarding pointers, breakdown sparkle, etc. Loads from
        /// the same Mascot/ namespace.
        case named(String)

        var assetName: String {
            switch self {
            case .onFire:        return "Mascot/PlootPointing"
            case .atRisk:        return "Mascot/PlootPleading"
            case .cold:          return "Mascot/PlootSleeping"
            case .named(let n):  return "Mascot/\(n)"
            }
        }
    }

    let pose: Pose
    var isDimmed: Bool = false

    init(_ pose: Pose, isDimmed: Bool = false) {
        self.pose = pose
        self.isDimmed = isDimmed
    }

    /// Convenience initializer that maps `TaskHelpers.StreakState` directly
    /// to the canonical mascot pose for that state.
    init(state: TaskHelpers.StreakState, isDimmed: Bool = false) {
        switch state {
        case .onFire: self.pose = .onFire
        case .atRisk: self.pose = .atRisk
        case .cold:   self.pose = .cold
        }
        self.isDimmed = isDimmed
    }

    var body: some View {
        Image(pose.assetName)
            .resizable()
            .scaledToFit()
            .opacity(isDimmed ? 0.55 : 1)
            .animation(Motion.spring, value: isDimmed)
            .transition(.scale.combined(with: .opacity))
            .id(pose.assetName)  // force a transition when the pose changes
    }
}

#Preview {
    HStack(spacing: 16) {
        PlootMascotView(.onFire).frame(width: 80, height: 80)
        PlootMascotView(.atRisk).frame(width: 80, height: 80)
        PlootMascotView(.cold).frame(width: 80, height: 80)
    }
    .padding()
    .background(Color(red: 1.0, green: 0.96, blue: 0.90))
}
