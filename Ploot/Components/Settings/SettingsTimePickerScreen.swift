import SwiftUI

/// Time-of-day picker pushed from a Settings row. Used for Check-in
/// time and the Quiet Hours start/end. Wraps a native iOS DatePicker in
/// the brand frame so the user gets the wheel they expect.
struct SettingsTimePickerScreen: View {
    let title: String
    let footer: String?
    @Binding var hour: Int
    @Binding var minute: Int
    var onChange: ((_ hour: Int, _ minute: Int) -> Void)? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var workingDate: Date = Date()

    var body: some View {
        ScreenFrame(
            title: title,
            leading: { HeaderButton(systemImage: "arrow.left") { dismiss() } }
        ) {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                pickerCard
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
                if let footer {
                    Text(footer)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .padding(.horizontal, Spacing.s4 + Spacing.s4)
                        .padding(.top, Spacing.s1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            workingDate = Calendar.current.date(
                bySettingHour: hour, minute: minute, second: 0, of: Date()
            ) ?? Date()
        }
        .onChange(of: workingDate) { _, newValue in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            let h = comps.hour ?? 0
            let m = comps.minute ?? 0
            hour = h
            minute = m
            onChange?(h, m)
        }
    }

    private var pickerCard: some View {
        DatePicker(
            "",
            selection: $workingDate,
            displayedComponents: [.hourAndMinute]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 0.6)
        )
    }
}
