import Foundation

extension Title {
  var stableNumericID: Int {
    if let id { return id }
    return stableDisplayID.unicodeScalars.reduce(17) { partial, scalar in
      ((partial &* 31) &+ Int(scalar.value)) & 0x3fffffff
    }
  }

  var stableDisplayID: String {
    if let id {
      let type = mediaType ?? (name == nil ? "movie" : "tv")
      return "\(type)-\(id)"
    }

    let rawName = title ?? name ?? "untitled"
    let normalizedName = rawName
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    let date = releaseDate ?? "unknown-date"
    let type = mediaType ?? (name == nil ? "movie" : "tv")
    return "\(type)-\(normalizedName)-\(date)"
  }
}

extension TitleDTO {
  var stableDisplayID: String {
    if let id {
      let type = mediaType ?? (name == nil ? "movie" : "tv")
      return "\(type)-\(id)"
    }

    let rawName = title ?? name ?? "untitled"
    let normalizedName = rawName
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    let date = releaseDate ?? firstAirDate ?? "unknown-date"
    let type = mediaType ?? (name == nil ? "movie" : "tv")
    return "\(type)-\(normalizedName)-\(date)"
  }
}
