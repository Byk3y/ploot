import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// Computed-property helpers and small action handlers used by the
// Settings screen's section layout. Pulled out of SettingsScreen.swift
// so the layout file stays focused on IA and bindings — these are pure
// transforms (formatters, label maps, option lists) plus the wipe /
// notification status handlers.

extension SettingsScreen {

    // MARK: - Daily routine helpers

    var currentStreakRule: UserPrefs.StreakRule {
        UserPrefs.StreakRule(rawValue: streakRuleRaw) ?? .anyTask
    }

    func formattedTime(hour: Int, minute: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    // MARK: - Reminders helpers

    var leadTimeOptions: [(value: Int, label: String, sublabel: String?)] {
        [
            (0, "At due time", nil),
            (5, "5 minutes before", nil),
            (15, "15 minutes before", nil),
            (30, "30 minutes before", nil),
            (60, "1 hour before", nil),
            (120, "2 hours before", nil)
        ]
    }

    func leadTimeLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "At due"
        case 5: return "5 min"
        case 15: return "15 min"
        case 30: return "30 min"
        case 60: return "1 hr"
        case 120: return "2 hr"
        default: return "\(minutes) min"
        }
    }

    var quietHoursValue: String {
        guard quietHoursEnabled else { return "Off" }
        return "\(formattedHour(quietHoursStart))–\(formattedHour(quietHoursEnd))"
    }

    func formattedHour(_ hour: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "h a"
        return fmt.string(from: date).lowercased()
    }

    var reminderStyleOptions: [(value: String, label: String, sublabel: String?)] {
        [
            ("gentle", "Gentle", "Friendly nudges. \"What's on the list today?\""),
            ("standard", "Standard", "Plain reminders, no fluff."),
            ("firm", "Firm", "Direct. \"Today's goal — 5 crushes.\""),
            ("none", "Off", "No daily check-in. Task reminders still fire.")
        ]
    }

    func reminderStyleLabel(_ raw: String) -> String {
        switch raw {
        case "gentle": return "Gentle"
        case "firm": return "Firm"
        case "none": return "Off"
        default: return "Standard"
        }
    }

    func statusLabel(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not asked"
        @unknown default: return "—"
        }
    }

    @MainActor
    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Quick add helpers

    var defaultProjectOptions: [(value: String, label: String, sublabel: String?)] {
        var options: [(value: String, label: String, sublabel: String?)] = [
            ("", "Inbox", "Catch-all when no project is set.")
        ]
        for project in allProjects where project.isLive {
            options.append((project.id, "\(project.emoji) \(project.name)", nil))
        }
        return options
    }

    var defaultProjectLabel: String {
        guard !defaultProjectId.isEmpty else { return "Inbox" }
        if let match = allProjects.first(where: { $0.id == defaultProjectId }) {
            return match.name
        }
        return "Inbox"
    }

    var currentDefaultSchedule: UserPrefs.DefaultSchedule {
        UserPrefs.DefaultSchedule(rawValue: defaultScheduleRaw) ?? .today
    }

    // MARK: - AI breakdown helpers

    var timelineOptions: [(value: String, label: String, sublabel: String?)] {
        [
            ("drip", "Drip", "First task today, rest dateless. One step at a time."),
            ("thisWeekend", "This weekend", "Spread across Saturday and Sunday."),
            ("thisWeek", "This week", "Spread across the rest of the week."),
            ("nextTwoWeeks", "Next 2 weeks", "Stretch across 14 days.")
        ]
    }

    func timelineLabel(_ raw: String) -> String {
        switch raw {
        case "drip": return "Drip"
        case "thisWeekend": return "This weekend"
        case "thisWeek": return "This week"
        case "nextTwoWeeks": return "Next 2 weeks"
        default: return "Drip"
        }
    }

    // MARK: - Today helpers

    var currentSortOrder: UserPrefs.SortOrder {
        UserPrefs.SortOrder(rawValue: sortOrderRaw) ?? .dueTime
    }

    // MARK: - Cleanup helpers

    var autoArchiveLabel: String {
        switch autoArchiveDays {
        case 0: return "Never"
        case 7: return "7 days"
        case 30: return "30 days"
        default: return "\(autoArchiveDays) days"
        }
    }

    // MARK: - Pro / subscription

    func openManageSubscription() {
        if subscription.isActive {
            showingManageSubscriptions = true
        } else {
            // Refresh + open anyway so the user sees current status
            // straight from Apple's sheet.
            Task { await subscription.loadProducts() }
            showingManageSubscriptions = true
        }
    }

    // MARK: - Help / mailto

    func openSupportEmail() {
        let body = "App version: \(appVersion)\nDevice: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let subject = "Ploot support"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Wipe-all-data action

    func wipeAllData() {
        // Soft-delete everything. softDelete() tombstones + pushes to
        // Supabase so the deletion propagates to other devices.
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
}

// MARK: - QuietHoursDetailScreen

/// Pushed from the Reminders → Quiet hours row. A toggle plus two hour
/// pickers. Kept as its own view (rather than reusing
/// SettingsTimePickerScreen) because quiet hours uniquely needs:
/// - an enabled toggle
/// - hour-only granularity (no minutes)
/// - two times in a single screen
struct QuietHoursDetailScreen: View {
    @Binding var enabled: Bool
    @Binding var startHour: Int
    @Binding var endHour: Int

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenFrame(
            title: "Quiet hours",
            leading: { HeaderButton(systemImage: "arrow.left") { dismiss() } }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    SettingsGroup(
                        footer: "When enabled, reminders that would fire inside the window are pushed to the next morning."
                    ) {
                        SettingsRow(
                            icon: "moon.stars",
                            label: "Enabled",
                            trailing: .toggle($enabled)
                        )
                    }

                    if enabled {
                        SettingsGroup(header: "Window") {
                            HStack {
                                Text("Start")
                                    .font(.geist(size: 16, weight: 500))
                                    .foregroundStyle(palette.fg1)
                                Spacer()
                                Picker("", selection: $startHour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(formattedHour(h)).tag(h)
                                    }
                                }
                                .labelsHidden()
                                .tint(palette.primary)
                            }
                            .padding(.horizontal, Spacing.s4)
                            .padding(.vertical, Spacing.s2)
                            .frame(minHeight: 48)

                            HStack {
                                Text("End")
                                    .font(.geist(size: 16, weight: 500))
                                    .foregroundStyle(palette.fg1)
                                Spacer()
                                Picker("", selection: $endHour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(formattedHour(h)).tag(h)
                                    }
                                }
                                .labelsHidden()
                                .tint(palette.primary)
                            }
                            .padding(.horizontal, Spacing.s4)
                            .padding(.vertical, Spacing.s2)
                            .frame(minHeight: 48)
                        }
                    }
                    Color.clear.frame(height: Spacing.s10)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(Motion.spring, value: enabled)
    }

    private func formattedHour(_ hour: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "h a"
        return fmt.string(from: date).lowercased()
    }
}

// MARK: - ShareSheet wrapper

/// Thin UIActivityViewController bridge so SwiftUI can present the
/// system share sheet for the App Store URL.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
