import SwiftUI

/// Sub-sheet wrapping a native graphical DatePicker. Presented over
/// QuickAddSheet when the user taps "Pick a date" — handles arbitrary
/// dates that don't fit any of the bucket pills (Today / Tomorrow /
/// Weekend / Next week).
struct DatePickerSheet: View {
    let initialDate: Date
    var onPick: (Date) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.plootPalette) private var palette

    init(initialDate: Date, onPick: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onPick = onPick
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack {
                Text("Pick a date")
                    .font(.fraunces(size: 18, weight: 600, soft: 80))
                    .foregroundStyle(palette.fg1)
                Spacer()
                Button("Done") {
                    onPick(date)
                    dismiss()
                }
                .buttonStyle(PlootButtonStyle(variant: .primary, size: .sm))
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.top, Spacing.s4)

            DatePicker(
                "",
                selection: $date,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, Spacing.s2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.bg)
    }
}
