import SwiftUI
import Lottie

/// Looping fire animation used by the streak surfaces. Mirrors brigo's
/// at-risk styling: pass `isDimmed: true` to drop opacity to 0.3 when the
/// streak is broken or today's first task isn't done yet.
///
/// The parsed `LottieAnimation` is cached as a static so every tab
/// remount shares the same in-memory animation tree — eliminates the
/// blank-frame flash that happened when each new view re-parsed the
/// 17.5KB JSON.
struct FireLottieView: View {
    var isDimmed: Bool = false

    private static let cachedAnimation: LottieAnimation? = LottieAnimation.named("Fire")

    /// Force the static cache to load on app launch so the first tab
    /// switch into a streak surface is already warm.
    static func preload() {
        _ = cachedAnimation
    }

    var body: some View {
        LottieView(animation: Self.cachedAnimation)
            .playing(loopMode: .loop)
            .opacity(isDimmed ? 0.3 : 1)
            .animation(Motion.spring, value: isDimmed)
    }
}

#Preview {
    HStack(spacing: 24) {
        FireLottieView()
            .frame(width: 64, height: 64)
        FireLottieView(isDimmed: true)
            .frame(width: 64, height: 64)
    }
    .padding()
    .background(Color(red: 0.99, green: 0.96, blue: 0.91))
}
