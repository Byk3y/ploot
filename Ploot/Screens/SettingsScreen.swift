import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import StoreKit

/// Settings home. The brand layer (Fraunces title, ink stroke, warm
/// fills) shows up at the screen scale; rows themselves stay quiet so
/// the screen scans top-to-bottom without visual shouting. See
/// `SettingsRow` and `SettingsGroup` for the shared row primitive.
///
/// IA priority (top → bottom): the things a user tweaks weekly come
/// first (Daily routine, Reminders, Quick add, AI breakdown, Today,
/// Cleanup); appearance + plan + account + legal anchor the bottom.
struct SettingsScreen: View {
    @Binding var theme: PlootTheme
    @Bindable var session: SessionManager

    @Query var allTasks: [PlootTask]
    @Query(sort: \PlootProject.order) var allProjects: [PlootProject]

    // Profile
    @AppStorage("displayName") var displayName: String = "You"
    @State var nameSyncTask: Task<Void, Never>? = nil

    // Daily routine
    @AppStorage(UserPrefs.Key.dailyGoal) var dailyGoal: Int = 5
    @AppStorage(UserPrefs.Key.checkinHour) var checkinHour: Int = 8
    @AppStorage(UserPrefs.Key.checkinMinute) var checkinMinute: Int = 47
    @AppStorage(UserPrefs.Key.trackStreak) var trackStreak: Bool = true
    @AppStorage(UserPrefs.Key.streakRule) var streakRuleRaw: String = UserPrefs.StreakRule.goalHit.rawValue

    // Reminders
    @AppStorage(UserPrefs.Key.autoRemindNew) var autoRemindNew: Bool = false
    @AppStorage(UserPrefs.Key.defaultLeadMinutes) var defaultLeadMinutes: Int = 0
    @AppStorage(UserPrefs.Key.quietHoursEnabled) var quietHoursEnabled: Bool = false
    @AppStorage(UserPrefs.Key.quietHoursStart) var quietHoursStart: Int = 22
    @AppStorage(UserPrefs.Key.quietHoursEnd) var quietHoursEnd: Int = 7
    @AppStorage(UserPrefs.Key.reminderStyle) var reminderStyle: String = "gentle"
    @AppStorage(UserPrefs.Key.hapticsEnabled) var hapticsEnabled: Bool = true

    // Quick add
    @AppStorage(UserPrefs.Key.defaultProjectId) var defaultProjectId: String = ""
    @AppStorage(UserPrefs.Key.defaultSchedule) var defaultScheduleRaw: String = UserPrefs.DefaultSchedule.noDate.rawValue

    // AI breakdown
    @AppStorage(UserPrefs.Key.useAIBreakdown) var useAIBreakdown: Bool = true
    @AppStorage(UserPrefs.Key.defaultTimelineMode) var defaultTimelineMode: String = "drip"
    @AppStorage(UserPrefs.Key.breakdownQuestions) var breakdownQuestions: Int = 3

    // Today
    @AppStorage(UserPrefs.Key.showOverdueSeparately) var showOverdueSeparately: Bool = true
    @AppStorage(UserPrefs.Key.autoRollIncomplete) var autoRollIncomplete: Bool = false
    @AppStorage(UserPrefs.Key.sortOrder) var sortOrderRaw: String = UserPrefs.SortOrder.dueTime.rawValue

    // Cleanup
    @AppStorage(UserPrefs.Key.autoArchiveDays) var autoArchiveDays: Int = 30
    @AppStorage(UserPrefs.Key.confirmBeforeDelete) var confirmBeforeDelete: Bool = true

    // Appearance
    // System locale drives the initial value when the user hasn't
    // chosen one yet. UserPrefs.weekStartsOn applies the same fallback
    // to non-@AppStorage reads.
    @AppStorage(UserPrefs.Key.weekStartsOn) var weekStartsOn: Int = Calendar.current.firstWeekday

    // Local UI state
    @State var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State var showingTestScreen: Bool = false
    @State var confirmingWipe: Bool = false
    @State var confirmingSignOut: Bool = false
    @State var confirmingDeleteAccount: Bool = false
    @State var showingManageSubscriptions: Bool = false
    @State var showingShareSheet: Bool = false

    @Bindable var subscription = SubscriptionManager.shared

    @Environment(\.plootPalette) var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.requestReview) var requestReview

    // Hosted public URLs — surfaced in About / Help. Update once a
    // marketing site exists; the App Store reviewer just needs the
    // links to resolve.
    static let supportEmail = "support@ploot.app"
    static let privacyURL = URL(string: "https://ploot.app/privacy")!
    static let termsURL = URL(string: "https://ploot.app/terms")!
    static let appStoreShareURL = URL(string: "https://apps.apple.com/app/id0000000000")!

    var body: some View {
        ScreenFrame(
            title: "Settings",
            leading: { HeaderButton(systemImage: "arrow.left") { dismiss() } }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    profileHeader
                    dailyRoutineSection
                    remindersSection
                    quickAddSection
                    aiBreakdownSection
                    todaySection
                    cleanupSection
                    appearanceSection
                    proSection
                    accountSection
                    helpSection
                    versionFooter
                    #if DEBUG
                    developerSection
                    #endif
                    Color.clear.frame(height: Spacing.s10)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await refreshNotificationStatus() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await refreshNotificationStatus() }
        }
        .navigationDestination(isPresented: $showingTestScreen) {
            TestScreen().toolbar(.hidden, for: .navigationBar)
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: ["Ploot — daily tasks that don't feel like work.", Self.appStoreShareURL])
        }
        .alert("Delete all data?", isPresented: $confirmingWipe) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) { wipeAllData() }
        } message: {
            Text("Every task, project, and subtask is gone. This can't be undone.")
        }
        .alert("Sign out?", isPresented: $confirmingSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("You'll need to sign back in with Apple next time. Your data stays put.")
        }
        .alert("Delete account?", isPresented: $confirmingDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Delete forever", role: .destructive) {
                Task { await session.deleteAccount() }
            }
        } message: {
            Text("Your account, every task, every project, and your subscription on this Apple ID — gone. This can't be undone.")
        }
    }

    // MARK: - Profile header

    var profileHeader: some View {
        HStack(spacing: Spacing.s4) {
            Text(TaskHelpers.avatarInitials(for: displayName))
                .font(.geist(size: 22, weight: 700))
                .foregroundStyle(palette.ink800)
                .frame(width: 64, height: 64)
                .background(Circle().fill(palette.butter300))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))

            VStack(alignment: .leading, spacing: 2) {
                TextField("Your name", text: $displayName)
                    .font(.fraunces(size: 22, weight: 600, opsz: 22, soft: 50))
                    .foregroundStyle(palette.fg1)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .onChange(of: displayName) { _, newValue in
                        // Debounce remote push so we don't hammer Supabase
                        // on every keystroke.
                        nameSyncTask?.cancel()
                        nameSyncTask = Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !Task.isCancelled else { return }
                            await session.updateRemoteDisplayName(newValue)
                        }
                    }
                if let email = session.currentUser?.email, !email.isEmpty {
                    Text(email)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s2)
    }

    // MARK: - Section: Daily routine

    var dailyRoutineSection: some View {
        SettingsGroup(
            header: "Daily routine",
            footer: "Streaks count once you hit your goal. Change to \"any task done\" if you want a softer rule."
        ) {
            NavigationLink {
                SettingsStepperScreen(
                    title: "Daily goal",
                    unitLabel: "tasks per day",
                    footer: "How many tasks you need to crush in a day for it to count toward your streak.",
                    range: 1...10,
                    value: $dailyGoal
                )
            } label: {
                SettingsRow(
                    icon: "target",
                    label: "Daily goal",
                    trailing: .value("\(dailyGoal) / day")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsTimePickerScreen(
                    title: "Check-in time",
                    footer: "When the daily check-in notification fires. Pick the time you usually plan your day.",
                    hour: $checkinHour,
                    minute: $checkinMinute,
                    onChange: { _, _ in
                        ReminderService.shared.scheduleDailyCheckin()
                    }
                )
            } label: {
                SettingsRow(
                    icon: "clock",
                    label: "Check-in time",
                    trailing: .value(formattedTime(hour: checkinHour, minute: checkinMinute))
                )
            }
            .buttonStyle(.plain)

            SettingsRow(
                icon: "flame",
                label: "Track streak",
                trailing: .toggle($trackStreak)
            )

            NavigationLink {
                SettingsOptionPicker(
                    title: "Streak rule",
                    footer: "What it takes for a day to count toward your streak.",
                    options: [
                        (UserPrefs.StreakRule.goalHit, "Goal hit", "You completed at least \(dailyGoal) tasks today."),
                        (UserPrefs.StreakRule.anyTask, "Any task done", "A single completion keeps the streak alive.")
                    ],
                    selection: Binding(
                        get: { UserPrefs.StreakRule(rawValue: streakRuleRaw) ?? .goalHit },
                        set: { streakRuleRaw = $0.rawValue }
                    )
                )
            } label: {
                SettingsRow(
                    icon: "checkmark.seal",
                    label: "Streak counts when…",
                    trailing: .value(currentStreakRule.label)
                )
            }
            .buttonStyle(.plain)
            .disabled(!trackStreak)
            .opacity(trackStreak ? 1 : 0.4)
        }
    }

    // MARK: - Section: Reminders

    var remindersSection: some View {
        SettingsGroup(
            header: "Reminders",
            footer: "Quiet hours pushes any reminder that would fire inside the window to the next morning."
        ) {
            SettingsRow(
                icon: "bell.badge",
                label: "Auto-remind new tasks",
                trailing: .toggle($autoRemindNew)
            )

            NavigationLink {
                SettingsOptionPicker(
                    title: "Default lead time",
                    footer: "How early before the due time the reminder fires.",
                    options: leadTimeOptions,
                    selection: $defaultLeadMinutes
                )
            } label: {
                SettingsRow(
                    icon: "timer",
                    label: "Default lead time",
                    trailing: .value(leadTimeLabel(defaultLeadMinutes))
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                QuietHoursDetailScreen(
                    enabled: $quietHoursEnabled,
                    startHour: $quietHoursStart,
                    endHour: $quietHoursEnd
                )
            } label: {
                SettingsRow(
                    icon: "moon.stars",
                    label: "Quiet hours",
                    trailing: .value(quietHoursValue)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsOptionPicker(
                    title: "Reminder tone",
                    footer: "How the daily check-in copy reads. Gentle is friendly; firm is matter-of-fact.",
                    options: reminderStyleOptions,
                    selection: $reminderStyle,
                    onChange: { _ in
                        ReminderService.shared.scheduleDailyCheckin()
                    }
                )
            } label: {
                SettingsRow(
                    icon: "text.bubble",
                    label: "Reminder tone",
                    trailing: .value(reminderStyleLabel(reminderStyle))
                )
            }
            .buttonStyle(.plain)

            SettingsRow(
                icon: "iphone.radiowaves.left.and.right",
                label: "Haptics",
                trailing: .toggle($hapticsEnabled)
            )

            Button(action: openSystemNotificationSettings) {
                SettingsRow(
                    icon: "gear",
                    label: "iOS notification permissions",
                    trailing: .value(statusLabel(notificationStatus))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: Quick add

    var quickAddSection: some View {
        SettingsGroup(
            header: "Quick add",
            footer: "What the + button does by default. Pick \"today\" to drop new tasks straight onto today's list."
        ) {
            NavigationLink {
                SettingsOptionPicker(
                    title: "Default project",
                    footer: "Where new tasks land if you don't pick one.",
                    options: defaultProjectOptions,
                    selection: $defaultProjectId
                )
            } label: {
                SettingsRow(
                    icon: "tray",
                    label: "Default project",
                    trailing: .value(defaultProjectLabel)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsOptionPicker(
                    title: "Default schedule",
                    footer: "Whether new tasks get \"today\" pre-selected or stay dateless.",
                    options: [
                        (UserPrefs.DefaultSchedule.today, "Today", "Drop new tasks onto today's list."),
                        (UserPrefs.DefaultSchedule.noDate, "No date", "Leave new tasks dateless until you pick.")
                    ],
                    selection: Binding(
                        get: { UserPrefs.DefaultSchedule(rawValue: defaultScheduleRaw) ?? .today },
                        set: { defaultScheduleRaw = $0.rawValue }
                    )
                )
            } label: {
                SettingsRow(
                    icon: "calendar",
                    label: "Default schedule",
                    trailing: .value(currentDefaultSchedule.label)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: AI breakdown

    var aiBreakdownSection: some View {
        SettingsGroup(
            header: "AI breakdown",
            footer: "When you create a project, Ploot can use AI to break it into bite-sized tasks. Turn off for fully-manual mode."
        ) {
            SettingsRow(
                icon: "sparkles",
                label: "Use AI breakdown",
                trailing: .toggle($useAIBreakdown)
            )

            NavigationLink {
                SettingsOptionPicker(
                    title: "Default timeline",
                    footer: "How AI-broken tasks get spread across your calendar by default.",
                    options: timelineOptions,
                    selection: $defaultTimelineMode
                )
            } label: {
                SettingsRow(
                    icon: "calendar.badge.clock",
                    label: "Default timeline",
                    trailing: .value(timelineLabel(defaultTimelineMode))
                )
            }
            .buttonStyle(.plain)
            .disabled(!useAIBreakdown)
            .opacity(useAIBreakdown ? 1 : 0.4)

            NavigationLink {
                SettingsStepperScreen(
                    title: "Clarifying questions",
                    unitLabel: "questions",
                    footer: "How many questions the AI is allowed to ask before it streams tasks. 0 = jump straight to tasks.",
                    range: 0...5,
                    value: $breakdownQuestions
                )
            } label: {
                SettingsRow(
                    icon: "questionmark.circle",
                    label: "Clarifying questions",
                    trailing: .value("\(breakdownQuestions)")
                )
            }
            .buttonStyle(.plain)
            .disabled(!useAIBreakdown)
            .opacity(useAIBreakdown ? 1 : 0.4)
        }
    }

    // MARK: - Section: Today

    var todaySection: some View {
        SettingsGroup(
            header: "Today",
            footer: "\"Auto-roll\" sweeps yesterday's untouched dated tasks onto today's list when you open the app."
        ) {
            SettingsRow(
                icon: "exclamationmark.triangle",
                label: "Show overdue separately",
                trailing: .toggle($showOverdueSeparately)
            )

            SettingsRow(
                icon: "arrow.uturn.forward",
                label: "Auto-roll incomplete",
                trailing: .toggle($autoRollIncomplete)
            )

            NavigationLink {
                SettingsOptionPicker(
                    title: "Sort by",
                    footer: "How tasks order inside Today and Project sections.",
                    options: [
                        (UserPrefs.SortOrder.dueTime, "Due time", "Earliest dated tasks first."),
                        (UserPrefs.SortOrder.created, "Created", "Newest first."),
                        (UserPrefs.SortOrder.priority, "Priority", "Urgent → high → medium → normal.")
                    ],
                    selection: Binding(
                        get: { UserPrefs.SortOrder(rawValue: sortOrderRaw) ?? .dueTime },
                        set: { sortOrderRaw = $0.rawValue }
                    )
                )
            } label: {
                SettingsRow(
                    icon: "arrow.up.arrow.down",
                    label: "Sort by",
                    trailing: .value(currentSortOrder.label)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: Cleanup

    var cleanupSection: some View {
        SettingsGroup(header: "Cleanup") {
            NavigationLink {
                SettingsOptionPicker(
                    title: "Auto-archive done",
                    footer: "Old completed tasks get archived (hidden, not deleted) so the Done list stays clean.",
                    options: [
                        (0, "Never", "Keep every completed task forever."),
                        (7, "After 7 days", "Tidy weekly."),
                        (30, "After 30 days", "Tidy monthly. (Recommended.)")
                    ],
                    selection: $autoArchiveDays
                )
            } label: {
                SettingsRow(
                    icon: "archivebox",
                    label: "Auto-archive done",
                    trailing: .value(autoArchiveLabel)
                )
            }
            .buttonStyle(.plain)

            SettingsRow(
                icon: "checkmark.circle",
                label: "Confirm before delete",
                trailing: .toggle($confirmBeforeDelete)
            )
        }
    }

    // MARK: - Section: Appearance

    var appearanceSection: some View {
        SettingsGroup(header: "Appearance") {
            NavigationLink {
                SettingsOptionPicker(
                    title: "Theme",
                    footer: "Light is the cream default. Cocoa is the warm dark mode (not pure black).",
                    options: [
                        (PlootTheme.light, "Light", "Cream + clay."),
                        (PlootTheme.cocoa, "Cocoa", "Warm chocolate.")
                    ],
                    selection: $theme
                )
            } label: {
                SettingsRow(
                    icon: "paintpalette",
                    label: "Theme",
                    trailing: .value(theme == .light ? "Light" : "Cocoa")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsOptionPicker(
                    title: "Week starts on",
                    footer: "Used for the streak chart on the Done screen and the calendar grid.",
                    options: [
                        (1, "Sunday", nil),
                        (2, "Monday", nil)
                    ],
                    selection: $weekStartsOn
                )
            } label: {
                SettingsRow(
                    icon: "calendar.day.timeline.left",
                    label: "Week starts on",
                    trailing: .value(weekStartsOn == 1 ? "Sunday" : "Monday")
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: Pro

    var proSection: some View {
        SettingsGroup(header: "Ploot Pro") {
            Button(action: openManageSubscription) {
                SettingsRow(
                    icon: "sparkle",
                    label: "Plan",
                    trailing: .value(subscription.isActive ? "Active" : "Inactive")
                )
            }
            .buttonStyle(.plain)

            Button(action: { Task { await subscription.restore() } }) {
                SettingsRow(
                    icon: "arrow.clockwise",
                    label: "Restore purchases"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: Account

    var accountSection: some View {
        SettingsGroup(header: "Account") {
            Button(action: { confirmingSignOut = true }) {
                SettingsRow(
                    icon: "arrow.right.square",
                    label: "Sign out"
                )
            }
            .buttonStyle(.plain)

            Button(action: { confirmingDeleteAccount = true }) {
                SettingsRow(
                    icon: "exclamationmark.octagon",
                    label: "Delete account",
                    destructive: true
                )
            }
            .buttonStyle(.plain)

            Button(action: { confirmingWipe = true }) {
                SettingsRow(
                    icon: "trash",
                    label: "Delete all data",
                    destructive: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section: Help

    var helpSection: some View {
        SettingsGroup(header: "Help") {
            Button(action: openSupportEmail) {
                SettingsRow(icon: "envelope", label: "Contact support")
            }
            .buttonStyle(.plain)

            Button(action: { requestReview() }) {
                SettingsRow(icon: "star", label: "Rate Ploot")
            }
            .buttonStyle(.plain)

            Button(action: { showingShareSheet = true }) {
                SettingsRow(icon: "square.and.arrow.up", label: "Share Ploot")
            }
            .buttonStyle(.plain)

            Link(destination: Self.privacyURL) {
                SettingsRow(
                    icon: "lock.shield",
                    label: "Privacy policy",
                    trailing: .disclosure
                )
            }

            Link(destination: Self.termsURL) {
                SettingsRow(
                    icon: "doc.text",
                    label: "Terms of service",
                    trailing: .disclosure
                )
            }
        }
    }

    // MARK: - Section: Developer (DEBUG only)

    var developerSection: some View {
        SettingsGroup(header: "Developer") {
            Button(action: { showingTestScreen = true }) {
                SettingsRow(
                    icon: "wrench.and.screwdriver",
                    label: "Design token test screen"
                )
            }
            .buttonStyle(.plain)

            SettingsRow(
                icon: "info.circle",
                label: "Tasks",
                trailing: .value("\(allTasks.count)")
            )
            SettingsRow(
                icon: "info.circle",
                label: "Projects",
                trailing: .value("\(allProjects.count)")
            )
        }
    }

    // MARK: - Version footer

    var versionFooter: some View {
        Text(appVersion)
            .font(.jetBrainsMono(size: 11, weight: 500))
            .foregroundStyle(palette.fg3)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.s2)
    }

    var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "v\(short) (\(build))"
    }
}
