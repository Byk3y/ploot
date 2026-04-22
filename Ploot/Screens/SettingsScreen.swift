import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Settings home. Pushed onto the root NavigationStack (not a sheet) so
/// each section has room to grow into detail panels later.
struct SettingsScreen: View {
    @Binding var theme: PlootTheme

    @Query private var allTasks: [PlootTask]
    @Query private var allProjects: [PlootProject]

    @AppStorage("displayName") private var displayName: String = "You"
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingTestScreen: Bool = false
    @State private var confirmingWipe: Bool = false

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScreenFrame(
            title: "Settings",
            leading: {
                HeaderButton(systemImage: "arrow.left") { dismiss() }
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    profileSection
                    section("Appearance") { appearanceRow }
                    section("Notifications") { notificationsRow }
                    section("Data") { dataRows }
                    section("About") { aboutRows }
                    section("Developer") { developerRow }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
            }
        }
        .task { await refreshNotificationStatus() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await refreshNotificationStatus() }
        }
        .navigationDestination(isPresented: $showingTestScreen) {
            TestScreen().toolbar(.hidden, for: .navigationBar)
        }
        .alert("Delete all data?", isPresented: $confirmingWipe) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) { wipeAllData() }
        } message: {
            Text("Every task, project, and subtask is gone. This can't be undone.")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        HStack(spacing: Spacing.s4) {
            Text(TaskHelpers.avatarInitials(for: displayName))
                .font(.geist(size: 20, weight: 700))
                .foregroundStyle(palette.ink800)
                .frame(width: 64, height: 64)
                .background(Circle().fill(palette.butter300))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))
                .stampedShadow(radius: 32, offset: 2)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Your name", text: $displayName)
                    .font(.fraunces(size: 22, weight: 600, opsz: 22, soft: 50))
                    .foregroundStyle(palette.fg1)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                Text("the initials show up on your Today avatar")
                    .font(.geist(size: 12, weight: 400))
                    .foregroundStyle(palette.fg3)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s2)
    }

    // MARK: - Section scaffolding

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title)
                .font(.jetBrainsMono(size: 11, weight: 600))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(palette.fg3)
                .padding(.leading, 2)

            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.md, offset: 2)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 1)
            .padding(.horizontal, Spacing.s4)
    }

    // MARK: - Appearance

    private var appearanceRow: some View {
        HStack {
            Text("Theme")
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg1)
            Spacer()
            HStack(spacing: 0) {
                ForEach(PlootTheme.allCases) { t in
                    Button {
                        withAnimation(Motion.spring) { theme = t }
                    } label: {
                        Text(t.rawValue)
                            .font(.geist(size: 12, weight: 600))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(theme == t ? palette.onPrimary : palette.fg2)
                            .background(Capsule().fill(theme == t ? palette.primary : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(palette.bgSunken))
            .overlay(Capsule().strokeBorder(palette.border, lineWidth: 1))
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    // MARK: - Notifications

    private var notificationsRow: some View {
        Button(action: openSystemSettings) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg1)
                    Text(statusSubtitle(notificationStatus))
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                Text(statusLabel(notificationStatus))
                    .font(.geist(size: 12, weight: 600))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .foregroundStyle(statusForeground(notificationStatus))
                    .background(Capsule().fill(statusBackground(notificationStatus)))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.fg3)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    private func statusLabel(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not asked"
        @unknown default: return "—"
        }
    }

    private func statusSubtitle(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized, .provisional, .ephemeral: return "you'll get a banner when a task is due"
        case .denied: return "tap to re-enable in Settings"
        case .notDetermined: return "toggle Remind me on any task to get asked"
        @unknown default: return ""
        }
    }

    private func statusForeground(_ s: UNAuthorizationStatus) -> Color {
        switch s {
        case .authorized, .provisional, .ephemeral: return palette.forest700
        case .denied: return palette.plum500
        default: return palette.fg2
        }
    }

    private func statusBackground(_ s: UNAuthorizationStatus) -> Color {
        switch s {
        case .authorized, .provisional, .ephemeral: return palette.forest100
        case .denied: return palette.plum100
        default: return palette.bgSunken
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Data

    private var dataRows: some View {
        VStack(spacing: 0) {
            labeledRow(label: "Tasks", value: "\(allTasks.count)")
            rowDivider
            labeledRow(label: "Projects", value: "\(allProjects.count)")
            rowDivider
            Button(action: { confirmingWipe = true }) {
                HStack {
                    Text("Delete all data")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.danger)
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.danger)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
            }
            .buttonStyle(.plain)
        }
    }

    private func wipeAllData() {
        // Cancel every pending reminder first so nothing orphaned fires
        // after the underlying task row is gone.
        for task in allTasks {
            ReminderService.shared.cancel(for: task)
        }
        for task in allTasks { modelContext.delete(task) }
        for project in allProjects { modelContext.delete(project) }
        try? modelContext.save()
    }

    // MARK: - About

    private var aboutRows: some View {
        VStack(spacing: 0) {
            labeledRow(label: "Version", value: appVersion)
            rowDivider
            Link(destination: URL(string: "https://github.com/Byk3y/ploot")!) {
                HStack {
                    Text("Source on GitHub")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg1)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.fg3)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
            }
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    // MARK: - Developer

    private var developerRow: some View {
        Button(action: { showingTestScreen = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Design token test screen")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg1)
                    Text("Phase 1 regression harness")
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.fg3)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    // MARK: - Row primitive

    private func labeledRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg1)
            Spacer()
            Text(value)
                .font(.jetBrainsMono(size: 13, weight: 500))
                .foregroundStyle(palette.fg2)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }
}
