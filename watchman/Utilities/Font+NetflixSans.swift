import SwiftUI

extension Font {
  enum NetflixWeight {
    case light
    case medium
    case bold

    var name: String {
      switch self {
      case .light: return "NetflixSans-Light"
      case .medium: return "NetflixSans-Medium"
      case .bold: return "NetflixSans-Bold"
      }
    }
  }

  static func netflixSans(_ weight: NetflixWeight = .medium, size: CGFloat) -> Font {
    return .custom(weight.name, size: size)
  }
}

// Helper modifiers for common text styles
extension View {
  func netflixFont(_ weight: Font.NetflixWeight = .medium, size: CGFloat) -> some View {
    self.font(.netflixSans(weight, size: size))
  }
}
