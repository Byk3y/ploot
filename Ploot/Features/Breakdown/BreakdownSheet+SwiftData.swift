import SwiftUI
import SwiftData

// SwiftData mutations spawned by the breakdown stream: insert each task
// as it arrives, soft-delete via context menu, and the "this is a task"
// hint shortcut. Pulled out of BreakdownSheet.swift to isolate the
// timeline + ordering logic from view rendering.

extension BreakdownSheet {

    /// Timeline model: ONLY the first task (order=0) goes into Today with
    /// a dueDate stamped for this morning. The rest go into `.later` with
    /// no dueDate — they live in the project, invisible in Today, until
    /// the user completes the one in motion (see ProjectTaskPromoter,
    /// which promotes the next .later task when one completes).
    ///
    /// createdAt ordering: streamed tasks arrive 60ms apart, so task 0
    /// has the earliest createdAt and task N the latest. But Today
    /// screen sorts by createdAt DESC, which flips the visible order.
    /// To preserve the AI's intended order under a DESC sort, we backdate
    /// each task by `order × 1ms` so task 0 is the newest (appears
    /// first) and task N is the oldest (appears last).
    @discardableResult
    func insertTask(emoji: String, title: String, order: Int) -> UUID {
        let composed = "\(emoji) \(title)"
        let isFirst = order == 0
        let section: TaskSection = isFirst ? .today : .later
        let dueDate: Date? = isFirst ? Self.firstTaskDueDate() : nil
        let task = PlootTask(
            title: composed,
            dueDate: dueDate,
            projectId: project.id,
            section: section,
            remindMe: isFirst
        )
        // Stamp createdAt so DESC sort preserves AI task order.
        task.createdAt = baseCreatedAt.addingTimeInterval(-Double(order) * 0.001)
        task.updatedAt = task.createdAt
        modelContext.insert(task)
        try? modelContext.save()
        if isFirst {
            ReminderService.shared.schedule(for: task)
        }
        SyncService.shared.push(task: task)
        return task.id
    }

    /// Due date for the first task in a breakdown. Always strictly in the
    /// future so reminders actually fire and the displayed time isn't
    /// already past. Anchored to the user's daily check-in time
    /// (`UserPrefs.checkinHour:checkinMinute`) — defaults 8:47 AM.
    /// - If now is before today's check-in: use today's check-in.
    /// - If now is in the active window (check-in → 22:00): round up to
    ///   the next half-hour mark.
    /// - If it's late evening (after 22:00): use tomorrow's check-in.
    static func firstTaskDueDate(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let checkinHour = UserPrefs.checkinHour
        let checkinMinute = UserPrefs.checkinMinute
        let startOfToday = cal.startOfDay(for: now)

        var checkinComps = DateComponents()
        checkinComps.year = cal.component(.year, from: startOfToday)
        checkinComps.month = cal.component(.month, from: startOfToday)
        checkinComps.day = cal.component(.day, from: startOfToday)
        checkinComps.hour = checkinHour
        checkinComps.minute = checkinMinute
        let checkinToday = cal.date(from: checkinComps) ?? startOfToday

        if now < checkinToday { return checkinToday }

        let lateCutoff = cal.date(byAdding: .hour, value: 22, to: startOfToday) ?? startOfToday
        if now >= lateCutoff,
           let tomorrowStart = cal.date(byAdding: .day, value: 1, to: startOfToday) {
            var tomorrowComps = DateComponents()
            tomorrowComps.year = cal.component(.year, from: tomorrowStart)
            tomorrowComps.month = cal.component(.month, from: tomorrowStart)
            tomorrowComps.day = cal.component(.day, from: tomorrowStart)
            tomorrowComps.hour = checkinHour
            tomorrowComps.minute = checkinMinute
            return cal.date(from: tomorrowComps) ?? tomorrowStart
        }

        let minute = cal.component(.minute, from: now)
        let bump = minute < 30 ? (30 - minute) : (60 - minute)
        let rounded = cal.date(byAdding: .minute, value: bump, to: now) ?? now
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        return cal.date(from: comps) ?? rounded
    }

    // MARK: - Timeline distribution

    /// Re-stamps every streamed task's dueDate to fit the chosen timeline
    /// window. Switching back to `.drip` restores the original "first
    /// task today, rest dateless" pattern so the chip is never misleading
    /// after the user toggles between modes.
    func applyTimeline(_ mode: TimelineMode) {
        let cal = Calendar.current
        let now = Date()

        if mode == .drip {
            for (idx, streamed) in streamedTasks.enumerated() {
                guard let task = fetchStreamedTask(streamed) else { continue }
                let isFirst = idx == 0
                task.dueDate = isFirst ? Self.firstTaskDueDate(now: now) : nil
                task.section = isFirst ? .today : .later
                task.remindMe = isFirst
                task.touch()
                if isFirst {
                    ReminderService.shared.schedule(for: task)
                } else {
                    ReminderService.shared.cancel(for: task)
                }
                SyncService.shared.push(task: task)
            }
            try? modelContext.save()
            return
        }

        let days = mode.days(now: now, calendar: cal)
        guard !days.isEmpty else { return }

        // Streamed tasks are already in AI order. Build a sorted slot
        // array (chronological) and pair task[i] → slot[i].
        let count = streamedTasks.count
        let slots = Self.scheduleSlots(days: days, count: count, calendar: cal, now: now)
        guard slots.count == count else { return }

        for (idx, streamed) in streamedTasks.enumerated() {
            guard let task = fetchStreamedTask(streamed) else { continue }
            let due = slots[idx]
            task.dueDate = due
            // Mirror section so list views that read .section directly
            // (project detail) still bucket correctly. derivedSection is
            // the source of truth for Today/Done.
            task.section = cal.isDate(due, inSameDayAs: now) ? .today : .later
            task.remindMe = true
            task.touch()
            ReminderService.shared.schedule(for: task)
            SyncService.shared.push(task: task)
        }
        try? modelContext.save()
    }

    private func fetchStreamedTask(_ streamed: StreamedTask) -> PlootTask? {
        let taskId = streamed.taskId
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private static func scheduleSlots(
        days: [Date],
        count: Int,
        calendar: Calendar,
        now: Date = Date()
    ) -> [Date] {
        guard !days.isEmpty, count > 0 else { return [] }
        let totalDays = days.count
        var raw: [Date] = []

        if count <= totalDays {
            // Spread tasks evenly across the window, one per chosen day,
            // anchored to 9 AM. Day index = floor(i × D / N) so task 0
            // lands on day 0 and task N-1 lands on day D-1.
            raw = (0..<count).compactMap { i in
                let dayIndex = min(Int(Double(i) * Double(totalDays) / Double(count)), totalDays - 1)
                return Self.dateAt(hour: 9, minute: 0, on: days[dayIndex], calendar: calendar)
            }
        } else {
            // More tasks than days: lay down 9 AM, 2 PM, 6 PM slots until
            // we have enough, then take the first N in chronological order.
            let slotHours = [9, 14, 18]
            var allSlots: [Date] = []
            for hour in slotHours {
                for day in days {
                    guard allSlots.count < count else { break }
                    if let date = Self.dateAt(hour: hour, minute: 0, on: day, calendar: calendar) {
                        allSlots.append(date)
                    }
                }
            }
            allSlots.sort()
            raw = Array(allSlots.prefix(count))
        }

        // Forward-clamp: any slot in the past gets pushed to the next
        // sensible future moment, and each subsequent slot must be at
        // least one hour after the previous one. Without this, a "this
        // week" pick at 3:51 PM Monday would put task 0 at "Today 9 AM"
        // (already past) and silently fail to schedule a reminder.
        let firstFuture = firstTaskDueDate(now: now)
        var clamped: [Date] = []
        var floor = now
        for slot in raw {
            var candidate = max(slot, firstFuture)
            if candidate <= floor {
                candidate = calendar.date(byAdding: .hour, value: 1, to: floor) ?? candidate
            }
            clamped.append(candidate)
            floor = candidate
        }
        return clamped
    }

    private static func dateAt(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)
    }

    func removeStreamedTask(_ streamed: StreamedTask) {
        // Soft-delete the real row so sync knows it's gone and the project
        // stops showing it. Then drop it from the sheet with a spring.
        let taskId = streamed.taskId
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            task.softDelete()
            try? modelContext.save()
        }
        withAnimation(Motion.spring) {
            streamedTasks.removeAll { $0.id == streamed.id }
            completedCount = max(0, completedCount - 1)
        }
    }

    /// User accepted the "this is a task, not a project" hint. Add the
    /// project title as a single task inside this project and close.
    func addAsSingleTask() {
        let task = PlootTask(
            title: project.name,
            projectId: project.id,
            section: .today
        )
        modelContext.insert(task)
        try? modelContext.save()
        SyncService.shared.push(task: task)
        closeSheet()
    }
}
