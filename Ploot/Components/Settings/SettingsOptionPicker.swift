import SwiftUI

/// Generic radio-style picker pushed from a Settings row. Each option
/// is rendered as a `SettingsRow` with a checkmark on the trailing edge
/// when it's the selected one. Picks up footer copy for context.
///
/// Used everywhere a setting is "pick one of N": streak rule, lead time,
/// reminder tone, default schedule, default project, timeline mode,
/// sort order, auto-archive, week start.
struct SettingsOptionPicker<Value: Hashable>: View {
    let title: String
    let footer: String?
    let options: [(value: Value, label: String, sublabel: String?)]
    @Binding var selection: Value
    var onChange: ((Value) -> Void)? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        footer: String? = nil,
        options: [(value: Value, label: String, sublabel: String?)],
        selection: Binding<Value>,
        onChange: ((Value) -> Void)? = nil
    ) {
        self.title = title
        self.footer = footer
        self.options = options
        self._selection = selection
        self.onChange = onChange
    }

    var body: some View {
        ScreenFrame(
            title: title,
            leading: { HeaderButton(systemImage: "arrow.left") { dismiss() } }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    SettingsGroup(footer: footer) {
                        ForEach(options.indices, id: \.self) { idx in
                            let opt = options[idx]
                            optionRow(value: opt.value, label: opt.label, sublabel: opt.sublabel)
                        }
                    }
                    Color.clear.frame(height: Spacing.s10)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func optionRow(value: Value, label: String, sublabel: String?) -> some View {
        Button {
            withAnimation(Motion.spring) { selection = value }
            onChange?(value)
        } label: {
            HStack(spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.geist(size: 16, weight: 500))
                        .foregroundStyle(palette.fg1)
                    if let sublabel {
                        Text(sublabel)
                            .font(.geist(size: 12, weight: 400))
                            .foregroundStyle(palette.fg3)
                    }
                }
                Spacer(minLength: Spacing.s2)
                if value == selection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: selection)
    }
}
