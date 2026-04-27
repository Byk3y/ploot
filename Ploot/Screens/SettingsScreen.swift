import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import StoreKit

/// Settings home. Pushed onto the root NavigationStack (not a sheet) so
/// each section has room to grow into detail panels later.
///
/// The individual section row views (appearance, subscription,
/// notifications, data, about, developer, account) live in
/// SettingsScreen+Sections.swift. Properties below are intentionally
/// internal so that extension can read them — same-file `private`
/// doesn't span files.
struct SettingsScreen: View {
    @Binding var theme: PlootTheme
    @Bindable var session: SessionManager

    @Query var allTasks: [PlootTask]
    @Query var allProjects: [PlootProject]

    @AppStorage("displayName") var displayName: String = "You"
    @State var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State var showingTestScreen: Bool = false
    @State var confirmingWipe: Bool = false
    @State var confirmingSignOut: Bool = false
    @State var nameSyncTask: Task<Void, Never>? = nil
    @State var showingManageSubscriptions: Bool = false

    @Bindable var subscription = SubscriptionManager.shared

    @Environment(\.plootPalette) var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext

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
                    section("Subscription") { subscriptionRow }
                    section("Data") { dataRows }
                    section("About") { aboutRows }
                    section("Developer") { developerRow }
                    section("Account") { accountRow }
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
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
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
                    .onChange(of: displayName) { _, newValue in
                        // Debounce remote push so we don't hammer Supabase
                        // on every keystroke. 500ms after the user stops
                        // typing, the change flushes up.
                        nameSyncTask?.cancel()
                        nameSyncTask = Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !Task.isCancelled else { return }
                            await session.updateRemoteDisplayName(newValue)
                        }
                    }
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

    func section<Content: View>(
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

    var rowDivider: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 1)
            .padding(.horizontal, Spacing.s4)
    }

    // MARK: - Row primitive

    func labeledRow(label: String, value: String) -> some View {
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
