import SwiftUI
import UIKit

extension View {
    /// Dismiss the keyboard when the user taps on any non-interactive region
    /// of this view. Buttons, TextFields, pickers, etc. consume their own
    /// taps first — this only fires on empty space.
    ///
    /// Two pieces make this reliable:
    ///   * `contentShape(Rectangle())` extends the hit region to the full
    ///     bounds of the view, including gaps between children. Without it,
    ///     SwiftUI stacks have no hit area in their empty space and the
    ///     gesture never fires.
    ///   * `UIResponder.resignFirstResponder` is sent through the responder
    ///     chain, so it dismisses any focused text input regardless of
    ///     whether it's a SwiftUI `TextField`, `TextEditor`, or a
    ///     `UIViewRepresentable`-wrapped UITextField.
    func dismissKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }
}
