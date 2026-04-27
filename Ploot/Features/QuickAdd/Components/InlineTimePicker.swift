import SwiftUI

/// Native compact time picker hung off QuickAddSheet's inline date row.
/// Bridges the picker's `Date` to the sheet's `String?` time-slot binding
/// using the same "h:mm a" format that submit() understands.
struct InlineTimePicker: View {
    @Binding var time: String?
    @State private var pickerDate: Date = Date()
    @State private var didLoad: Bool = false

    var body: some View {
        DatePicker("", selection: $pickerDate, displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .labelsHidden()
            .onAppear {
                if let time, let parsed = Self.parse(time) {
                    pickerDate = parsed
                }
                didLoad = true
            }
            .onChange(of: pickerDate) { _, newDate in
                guard didLoad else { return }
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = "h:mm a"
                time = fmt.string(from: newDate)
            }
            .onChange(of: time) { _, newTime in
                guard let newTime, let parsed = Self.parse(newTime) else { return }
                if Calendar.current.compare(parsed, to: pickerDate, toGranularity: .minute) != .orderedSame {
                    pickerDate = parsed
                }
            }
    }

    private static func parse(_ str: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        return fmt.date(from: str)
    }
}
