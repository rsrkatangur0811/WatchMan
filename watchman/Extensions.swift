import SwiftUI

extension AnyTransition {
  static var genrePill: AnyTransition {
    .asymmetric(
      insertion: .move(edge: .leading).combined(with: .opacity),
      removal: .move(edge: .trailing).combined(with: .opacity)
    )
  }
}
