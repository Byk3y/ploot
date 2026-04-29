import SwiftUI

/// Empty-state surfaces lead with Ploot the cat, not an SF Symbol.
/// `mascotPose` picks which Ploot shows up — defaults to the
/// "victory lap" `PlootDone` for "all done" type messages and
/// `PlootConfused` for "nothing here" type messages. Callers that
/// don't pass a mascot pose still get a Ploot, just the default one
/// for `systemImage == "tray"` heuristic.
struct EmptyState<Action: View>: View {
    /// Legacy hook — still accepted but ignored when `mascotPose` is
    /// set. Kept so existing call sites don't all need to migrate at
    /// once. New call sites should pass `mascotPose:` instead.
    var systemImage: String?
    var mascotPose: PlootMascotView.Pose
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var action: () -> Action

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: Spacing.s3) {
            PlootMascotView(mascotPose)
                .frame(width: 140, height: 140)
                .padding(.bottom, 4)
            Text(title)
                .font(.fraunces(size: 24, weight: 600))
                .tracking(-0.015 * 24)
                .foregroundStyle(palette.fg1)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.geist(size: 14, weight: 400))
                    .foregroundStyle(palette.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .lineSpacing(4)
            }
            action()
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyState where Action == EmptyView {
    /// New preferred initializer — pick the mascot pose explicitly.
    init(
        mascotPose: PlootMascotView.Pose,
        title: String,
        subtitle: String? = nil
    ) {
        self.systemImage = nil
        self.mascotPose = mascotPose
        self.title = title
        self.subtitle = subtitle
        self.action = { EmptyView() }
    }

    /// Back-compat for existing callers that pass an SF Symbol. Maps
    /// the symbol to a sensible Ploot pose so the screen still gets
    /// the right vibe without every call site needing edits.
    init(systemImage: String? = nil, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.mascotPose = Self.poseForSymbol(systemImage)
        self.title = title
        self.subtitle = subtitle
        self.action = { EmptyView() }
    }

    private static func poseForSymbol(_ symbol: String?) -> PlootMascotView.Pose {
        switch symbol {
        case "flag.checkered":  return .named("PlootPointing")    // "All done!" — celebratory until PlootDone art lands
        case "tray":            return .named("PlootConfused")    // "Nothing here"
        case "calendar":        return .named("PlootPeeking")     // calendar empty — falls back until PlootResearch art lands
        case "folder":          return .named("PlootConfused")    // empty project
        default:                return .named("PlootConfused")
        }
    }
}
