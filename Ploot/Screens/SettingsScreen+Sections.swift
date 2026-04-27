import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// All the content rows that hang off SettingsScreen's `section(...)`
// scaffolding — appearance, subscription, notifications, data, about,
// developer, and account. Pulled out of SettingsScreen.swift so that
// file can stay focused on layout chrome (profile + section frame +
// labeled-row primitive).

extension SettingsScreen {

    // MARK: - Appearance

    var appearanceRow: some View {
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

    // MARK: - Subscription

    var subscriptionRow: some View {
        Button(action: openManage) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ploot Pro")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg1)
                    Text(subscriptionSubtitle)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                Text(subscriptionStatusLabel)
                    .font(.geist(size: 12, weight: 600))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .foregroundStyle(subscription.isActive ? palette.onPrimary : palette.fg2)
                    .background(
                        Capsule().fill(subscription.isActive ? palette.primary : palette.bgSunken)
                    )
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.fg3)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    var subscriptionStatusLabel: String {
        subscription.isActive ? "Active" : "Inactive"
    }

    var subscriptionSubtitle: String {
        if subscription.isActive {
            return "tap to manage plan, cancel, or switch to yearly"
        } else {
            return "your trial or subscription isn't active"
        }
    }

    func openManage() {
        if subscription.isActive {
            showingManageSubscriptions = true
        } else {
            // No active subscription — StoreKit's manage sheet would
            // just say "nothing to manage". Kick off a refresh + open
            // anyway so the user sees the status from Apple directly.
            Task { await subscription.loadProducts() }
            showingManageSubscriptions = true
        }
    }

    // MARK: - Notifications

    var notificationsRow: some View {
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

    func statusLabel(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not asked"
        @unknown default: return "—"
        }
    }

    func statusSubtitle(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized, .provisional, .ephemeral: return "you'll get a banner when a task is due"
        case .denied: return "tap to re-enable in Settings"
        case .notDetermined: return "toggle Remind me on any task to get asked"
        @unknown default: return ""
        }
    }

    func statusForeground(_ s: UNAuthorizationStatus) -> Color {
        switch s {
        case .authorized, .provisional, .ephemeral: return palette.forest700
        case .denied: return palette.plum500
        default: return palette.fg2
        }
    }

    func statusBackground(_ s: UNAuthorizationStatus) -> Color {
        switch s {
        case .authorized, .provisional, .ephemeral: return palette.forest100
        case .denied: return palette.plum100
        default: return palette.bgSunken
        }
    }

    @MainActor
    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Data

    var dataRows: some View {
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

    func wipeAllData() {
        // Soft-delete everything. softDelete() tombstones + pushes to
        // Supabase so the deletion propagates to other devices. Hard
        // delete would just get re-pulled on the next foreground.
        for task in allTasks {
            ReminderService.shared.cancel(for: task)
            for sub in task.subtasks where sub.isLive {
                sub.softDelete()
            }
            if task.isLive {
                task.softDelete()
            }
        }
        for project in allProjects where project.isLive {
            project.softDelete()
        }
        try? modelContext.save()
    }

    // MARK: - About

    var aboutRows: some View {
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

    var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    // MARK: - Developer

    var developerRow: some View {
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

    // MARK: - Account

    var accountRow: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg1)
                    Text(session.currentUser?.email ?? "—")
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)

            rowDivider

            Button(action: { confirmingSignOut = true }) {
                HStack {
                    Text("Sign out")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.danger)
                    Spacer()
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.danger)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
            }
            .buttonStyle(.plain)
        }
    }
}
