import SwiftUI
import UIKit

/// A text field that forces the iOS emoji keyboard. iOS has no standalone
/// emoji picker surface exposed to SwiftUI, but you can override two
/// properties on UITextField — `textInputContextIdentifier` and
/// `textInputMode` — to make the emoji keyboard the only one the field
/// will present. Tap the field → emoji keyboard pops up directly, no globe
/// key hunt.
///
/// The coordinator truncates input to the last single character so the
/// stored value is always one emoji.
struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    /// When true, render the caret and typed glyphs transparently so the
    /// field can sit invisibly behind / on top of a tappable tile. The
    /// selected emoji is always read from the `text` binding; the field
    /// itself only exists to trigger the emoji keyboard.
    var hidesCursor: Bool = false

    func makeUIView(context: Context) -> UITextField {
        let field = _ForcedEmojiUITextField()
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 18)
        field.autocorrectionType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        if hidesCursor {
            field.tintColor = .clear
            field.textColor = .clear
        }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = (textField.text ?? "") as NSString
            let after = current.replacingCharacters(in: range, with: string)
            if let last = after.last {
                let one = String(last)
                text = one
                textField.text = one
            } else {
                text = ""
                textField.text = ""
            }
            return false
        }
    }
}

/// Private subclass used only by EmojiTextField. Overrides the two inputs
/// UIKit consults when deciding which keyboard to present.
private final class _ForcedEmojiUITextField: UITextField {
    override var textInputContextIdentifier: String? { "ploot.emoji" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
            ?? super.textInputMode
    }
}
