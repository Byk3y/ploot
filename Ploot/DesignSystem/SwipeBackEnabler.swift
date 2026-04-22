import UIKit

/// Keeps the iOS interactive "swipe-from-left-edge to pop" gesture working
/// even when the navigation bar is hidden via SwiftUI's `.toolbar(.hidden, …)`.
///
/// SwiftUI's NavigationStack wraps UIKit's UINavigationController. When the
/// nav bar is fully hidden, UIKit's default delegate disables the
/// interactivePopGestureRecognizer. Reassigning its delegate and always
/// allowing the gesture to begin (when there's a screen to pop back to)
/// restores the expected behavior.
///
/// This is a long-standing, widely used idiom; the @retroactive conformance
/// is required in Swift 6.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
