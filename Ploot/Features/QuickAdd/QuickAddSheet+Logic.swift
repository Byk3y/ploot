import SwiftUI
import SwiftData
import UIKit

// State setters, NLP parser, and submit/save logic for QuickAddSheet.
// Pulled out so QuickAddSheet.swift stays focused on layout. The
// setters mark fields as user-set so subsequent NLP runs leave them
// alone; submit reads the user-set fields and either updates an
// existing PlootTask in place or inserts a new one.

extension QuickAddSheet {

    // MARK: - State setters (mark fields as user-set)

    func setDue(_ option: DueOption) {
        withAnimation(Motion.spring) {
            customDate = nil
            due = option
            dateUserSet = true
        }
        datePulse &+= 1
    }

    func setCustomDate(_ date: Date) {
        withAnimation(Motion.spring) {
            customDate = date
            // Pin `due` to .someday when customDate is in play; submit logic
            // prefers customDate. fromDate would also map most arbitrary
            // dates to .someday anyway.
            due = .someday
            dateUserSet = true
        }
        datePulse &+= 1
    }

    func setProject(_ id: String) {
        withAnimation(Motion.spring) {
            projectId = id
            projectUserSet = true
            projectPickerOpen = false
        }
        projectPulse &+= 1
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - NLP

    /// Light parser for inline cues. Only fills fields the user hasn't
    /// touched manually. Doesn't *clear* fields when the cue is removed —
    /// that would feel jumpy as the user edits the title; explicit pill
    /// taps clear instead.
    func applyNLP(from raw: String) {
        let lower = raw.lowercased()

        if !dateUserSet {
            var newDue: DueOption?
            if lower.range(of: #"\btomorrow\b"#, options: .regularExpression) != nil {
                newDue = .tomorrow
            } else if lower.range(of: #"\btoday\b"#, options: .regularExpression) != nil {
                newDue = .today
            } else if lower.range(of: #"\b(this )?weekend\b"#, options: .regularExpression) != nil {
                newDue = .weekend
            } else if lower.range(of: #"\bnext week\b"#, options: .regularExpression) != nil {
                newDue = .nextweek
            }
            if let newDue, newDue != due {
                due = newDue
                customDate = nil
                datePulse &+= 1
            }

            if let parsed = Self.parseTime(from: lower), parsed != time {
                time = parsed
                datePulse &+= 1
            }
        }

        if !priorityUserSet {
            var newPriority: Priority?
            if lower.range(of: #"\burgent\b|!!!"#, options: .regularExpression) != nil {
                newPriority = .urgent
            } else if lower.contains("!!") {
                newPriority = .high
            } else if lower.range(of: #"!(\s|$)"#, options: .regularExpression) != nil {
                newPriority = .medium
            }
            if let newPriority, newPriority != priority {
                priority = newPriority
            }
        }

        if !projectUserSet {
            if let m = lower.range(of: #"@(\w+)"#, options: .regularExpression) {
                let mention = String(lower[m]).dropFirst()
                if let proj = allProjects.first(where: {
                    $0.name.lowercased() == mention || $0.id.lowercased() == mention
                }), projectId != proj.id {
                    projectId = proj.id
                    projectPulse &+= 1
                }
            }
        }
    }

    static func parseTime(from text: String) -> String? {
        let patterns = [
            #"\b(1[0-2]|0?[1-9]):([0-5][0-9])\s*(am|pm)\b"#,
            #"\b(1[0-2]|0?[1-9])\s*(am|pm)\b"#
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let str = String(text[match])
                if let normalized = normalize(timeStr: str) {
                    return normalized
                }
            }
        }
        return nil
    }

    static func normalize(timeStr: String) -> String? {
        let cleaned = timeStr.replacingOccurrences(of: " ", with: "")
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for inputFmt in ["h:mma", "ha"] {
            fmt.dateFormat = inputFmt
            if let date = fmt.date(from: cleaned) {
                fmt.dateFormat = "h:mm a"
                return fmt.string(from: date)
            }
        }
        return nil
    }

    // MARK: - Actions

    func addSubtask() {
        let trimmed = subInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(Motion.springFast) {
            subtasks.append(Subtask(title: trimmed, order: subtasks.count))
        }
        subInput = ""
    }

    func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let resolvedDate: Date? = {
            if let customDate {
                return Self.applyTimeSlot(time, to: customDate)
            }
            return due.date(timeSlot: time)
        }()
        let resolvedProjectId: String? = projectId == "inbox" ? nil : projectId
        let resolvedRepeats: String? = repeats == .never ? nil : repeats.rawValue
        let resolvedNote: String? = note.isEmpty ? nil : note

        let savedTask: PlootTask
        if let existing = existingTask {
            existing.title = trimmed
            existing.note = resolvedNote
            existing.dueDate = resolvedDate
            existing.due = nil
            existing.projectId = resolvedProjectId
            existing.priority = priority
            existing.repeats = resolvedRepeats
            existing.remindMe = remindMe
            let keptIds = Set(subtasks.map(\.id))
            for old in existing.subtasks where !keptIds.contains(old.id) {
                old.softDelete()
            }
            existing.subtasks = subtasks
            existing.touch()
            savedTask = existing
        } else {
            let task = PlootTask(
                title: trimmed,
                note: resolvedNote,
                due: nil,
                dueDate: resolvedDate,
                projectId: resolvedProjectId,
                priority: priority,
                subtasks: subtasks,
                section: .today,
                repeats: resolvedRepeats,
                remindMe: remindMe
            )
            modelContext.insert(task)
            savedTask = task
        }
        try? modelContext.save()
        SyncService.shared.push(task: savedTask)

        if remindMe {
            Task {
                _ = await ReminderService.shared.requestAuthorizationIfNeeded()
                await MainActor.run {
                    ReminderService.shared.schedule(for: savedTask)
                }
            }
        } else {
            ReminderService.shared.cancel(for: savedTask)
        }

        onClose()
    }

    static func applyTimeSlot(_ slot: String?, to date: Date) -> Date {
        guard let slot else { return date }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        guard let parsed = fmt.date(from: slot) else { return date }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: parsed)
        let minute = cal.component(.minute, from: parsed)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
