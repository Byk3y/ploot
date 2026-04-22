import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var session: SessionManager

    @State private var tab: PlootTab = .today
    @State private var quickAddOpen: Bool = false
    @State private var openSettings: Bool = false
    @State private var openTask: PlootTask? = nil
    @State private var openProject: PlootProject? = nil
    @State private var theme: PlootTheme = .light

    @Environment(\.plootPalette) private var palette

    var body: some View {
        NavigationStack {
            tabContent
                .overlay(alignment: .bottomTrailing) {
                    // Order matters: overlay applies before .safeAreaInset so
                    // the FAB anchors to the tab content's bottom (the tab
                    // bar's top) and doesn't cover any tab.
                    //
                    // Hidden on the Projects tab — the screen already has a
                    // header-level "+" that creates a project, and a second
                    // FAB that creates tasks was easy to confuse with it.
                    if tab != .projects {
                        FAB(action: { quickAddOpen = true })
                            .padding(.trailing, 20)
                            .padding(.bottom, 12)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .animation(Motion.spring, value: tab)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TabBar(current: $tab)
                }
                .background(palette.bg.ignoresSafeArea())
                .navigationDestination(item: $openTask) { task in
                    TaskDetailScreen(task: task)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
                .navigationDestination(item: $openProject) { project in
                    ProjectDetailScreen(project: project)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
                .navigationDestination(isPresented: $openSettings) {
                    SettingsScreen(theme: $theme, session: session)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
        }
        .plootTheme(theme)
        .sheet(isPresented: $quickAddOpen) {
            QuickAddSheet(onClose: { quickAddOpen = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .plootTheme(theme)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .today:
            TodayScreen(
                onOpen: { openTask = $0 },
                onOpenSettings: { openSettings = true }
            )
        case .projects:
            ProjectsScreen(onOpenProject: { openProject = $0 })
        case .calendar:
            CalendarScreen()
        case .done:
            DoneScreen(onOpen: { openTask = $0 })
        }
    }
}
