import SwiftUI
import Lottie

/// Looping fire animation used by the Done streak card. Mirrors brigo's
/// at-risk styling: pass `isDimmed: true` to drop opacity to 0.3 when the
/// streak is broken or today's first task isn't done yet.
struct FireLottieView: View {
    var isDimmed: Bool = false

    var body: some View {
        LottieView(animation: .named("Fire"))
            .playing(loopMode: .loop)
            .opacity(isDimmed ? 0.3 : 1)
            .animation(Motion.spring, value: isDimmed)
    }
}

#Preview {
    HStack(spacing: 24) {
        FireLottieView()
        FireLottieView(isDimmed: true)
    }
    .padding()
    .background(Color(red: 0.99, green: 0.96, blue: 0.91))
}
