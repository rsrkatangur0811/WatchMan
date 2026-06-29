import CoreText
import SwiftUI

struct FontLoader {
  static func registerFonts() {
    let fontNames = [
      "Netflix Sans Bold",
      "Netflix Sans Light",
      "Netflix Sans Medium",
    ]

    for name in fontNames {
      guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else {
        continue
      }

      var error: Unmanaged<CFError>?
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
  }
}
