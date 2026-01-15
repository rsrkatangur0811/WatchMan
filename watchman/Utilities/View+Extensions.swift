import SwiftUI
import UIKit

extension View {
  /// Applies the given transform if the given condition evaluates to `true`.
  /// - Parameters:
  ///   - condition: The condition to evaluate.
  ///   - transform: The transform to apply to the source `View`.
  /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
  @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content)
    -> some View
  {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}

// MARK: - Screen Corner Radius Helper

extension UIScreen {
  /// Returns the corner radius of the device's screen.
  /// Uses private API via KVC to get the actual hardware corner radius.
  /// Falls back to 47pt (standard iPhone 15 curve) if the key is missing.
  static var screenCornerRadius: CGFloat {
    // "_displayCornerRadius" is the internal key Apple uses for the screen's physical corner radius
    guard let cornerRadius = UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat else {
      return 47  // Safe fallback for modern iPhones
    }
    return cornerRadius
  }
}
