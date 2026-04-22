import SwiftUI

@main
struct PlootApp: App {
    init() {
        PlootFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
