import SwiftUI

struct CalendarScreen: View {
    @Bindable var store: TaskStore

    @State private var selected: Date = Date()
    @Environment(\.plootPalette) private var palette

    private var days: [Date] {
        let cal = Calendar.current
        let today = Date()
        return (-2...25).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }
    }

    private let timeSlots: [String] = ["8 AM", "10 AM", "12 PM", "2 PM", "4 PM"]
    private let slotColors: [ProjectTileColor] = [.primary, .forest, .butter, .sky, .plum]

    var body: some View {
        ScreenFrame(
            title: "Calendar",
            subtitle: "Plan the shape of your week."
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    dayScrubber
                    timeline
                    Color.clear.frame(height: 120)
                }
            }
        }
    }

    private var dayScrubber: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(days, id: \.self) { day in
                    DayTile(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selected),
                        isToday: Calendar.current.isDateInToday(day),
                        onTap: {
                            withAnimation(Motion.spring) {
                                selected = day
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.top, Spacing.s1)
            .padding(.bottom, Spacing.s4)
        }
    }

    private var timeline: some View {
        let dayTasks = Array(store.tasks(in: .today).prefix(4))
        return VStack(spacing: Spacing.s2) {
            ForEach(Array(timeSlots.enumerated()), id: \.offset) { i, slot in
                HStack(alignment: .top, spacing: 14) {
                    Text(slot)
                        .font(.jetBrainsMono(size: 11, weight: 500))
                        .foregroundStyle(palette.fg3)
                        .frame(width: 48, alignment: .leading)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Rectangle()
                            .fill(palette.border)
                            .frame(height: 1)
                        if i < dayTasks.count {
                            timelineCard(task: dayTasks[i], colorIdx: i)
                        } else {
                            Color.clear.frame(height: 40)
                        }
                    }
                }
                .frame(minHeight: 48)
            }
        }
        .padding(.horizontal, Spacing.s4)
    }

    private func timelineCard(task: PlootTask, colorIdx: Int) -> some View {
        let tint = slotColors[colorIdx % slotColors.count]
        let tintColor = tint.fill(palette: palette).opacity(palette.ink50 == .white ? 0.22 : 0.28)
        return VStack(alignment: .leading, spacing: 2) {
            Text(task.title)
                .font(.geist(size: 14, weight: 600))
                .foregroundStyle(palette.fg1)
                .lineLimit(1)
            Text(task.duration ?? "30 min")
                .font(.geist(size: 12, weight: 400))
                .foregroundStyle(palette.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: Radius.md, padding: 10, fill: tintColor)
    }
}

private struct DayTile: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(Self.weekdayShort(date))
                    .font(.jetBrainsMono(size: 10, weight: 600))
                    .tracking(10 * 0.08)
                    .textCase(.uppercase)
                    .opacity(0.8)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.fraunces(size: 22, weight: 600))

                if isToday {
                    Circle()
                        .fill(isSelected ? palette.onPrimary : palette.primary)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(minWidth: 52)
            .padding(.vertical, 10)
            .padding(.horizontal, Spacing.s2)
            .foregroundStyle(isSelected ? palette.onPrimary : palette.fg1)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isSelected ? palette.primary : palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.borderInk : palette.border,
                        lineWidth: 2
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.borderInk)
                    .offset(y: isSelected ? 2 : 0)
                    .opacity(isSelected ? 1 : 0)
            )
            .offset(y: isSelected ? -2 : 0)
        }
        .buttonStyle(.plain)
    }

    private static func weekdayShort(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }
}
