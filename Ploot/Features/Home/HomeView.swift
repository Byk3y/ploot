import SwiftUI

struct HomeView: View {
    @State private var store = TaskStore()
    @State private var tab: PlootTab = .today
    @State private var quickAddOpen: Bool = false
    @State private var settingsOpen: Bool = false
    @State private var openTask: PlootTask? = nil
    @State private var theme: PlootTheme = .light

    @Environment(\.plootPalette) private var palette

    var body: some View {
        NavigationStack {
            tabContent
                .overlay(alignment: .bottomTrailing) {
                    // Ordering matters: this overlay is applied to tabContent
                    // *before* .safeAreaInset. That anchors the FAB to the
                    // bottom of the content area, which is the top of the
                    // TabBar — so it floats 12pt above the bar instead of
                    // over it, regardless of device safe-area size.
                    FAB(action: { quickAddOpen = true })
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TabBar(current: $tab)
                }
                .background(palette.bg.ignoresSafeArea())
            .navigationDestination(item: $openTask) { task in
                TaskDetailScreen(store: store, taskId: task.id)
                    .navigationBarBackButtonHidden()
                    .toolbar(.hidden, for: .navigationBar)
                    .plootTheme(theme)
            }
        }
        .plootTheme(theme)
        .sheet(isPresented: $quickAddOpen) {
            QuickAddSheet(store: store, onClose: { quickAddOpen = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .plootTheme(theme)
        }
        .sheet(isPresented: $settingsOpen) {
            SettingsSheet(theme: $theme, onClose: { settingsOpen = false })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .plootTheme(theme)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .today:
            TodayScreen(
                store: store,
                onOpen: { openTask = $0 },
                onOpenSettings: { settingsOpen = true }
            )
        case .projects:
            ProjectsScreen(store: store)
        case .calendar:
            CalendarScreen(store: store)
        case .done:
            DoneScreen(store: store, onOpen: { openTask = $0 })
        }
    }
}

/// Lightweight settings sheet exposing the theme switcher and a link to the
/// Phase 1 test screen for quick visual regressions.
struct SettingsSheet: View {
    @Binding var theme: PlootTheme
    var onClose: () -> Void

    @State private var showingTestScreen: Bool = false
    @Environment(\.plootPalette) private var palette

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Theme")
                        .font(.jetBrainsMono(size: 11, weight: 600))
                        .tracking(11 * 0.08)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.fg3)
                    HStack(spacing: 0) {
                        ForEach(PlootTheme.allCases) { t in
                            Button {
                                withAnimation(Motion.spring) { theme = t }
                            } label: {
                                Text(t.rawValue)
                                    .font(.geist(size: 13, weight: 600))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(theme == t ? palette.onPrimary : palette.fg2)
                                    .background(
                                        Capsule().fill(theme == t ? palette.primary : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Capsule().fill(palette.bgSunken))
                    .overlay(Capsule().strokeBorder(palette.border, lineWidth: 1))
                }

                Button {
                    showingTestScreen = true
                } label: {
                    HStack {
                        Text("Open design-token test screen")
                            .font(.geist(size: 15, weight: 600))
                            .foregroundStyle(palette.fg1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.fg3)
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle(radius: Radius.md, padding: Spacing.s4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s5)
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .font(.geist(size: 15, weight: 600))
                        .foregroundStyle(palette.primary)
                }
            }
            .navigationDestination(isPresented: $showingTestScreen) {
                TestScreen()
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
