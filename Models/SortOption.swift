import Foundation

enum SortOption: String, CaseIterable, Identifiable {
  case defaults = "Default"
  case popularity = "Popularity"
  case name = "Name"
  case releaseDate = "Release Date"
  case rating = "Highest Rated"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .defaults: return "arrow.up.arrow.down"
    case .popularity: return "flame"
    case .name: return "textformat.abc"
    case .releaseDate: return "calendar"
    case .rating: return "star"
    }
  }

  func apiValue(mediaType: String) -> String {
    switch self {
    case .defaults, .popularity:
      return "popularity.desc"
    case .name:
      return mediaType == "tv" ? "original_name.asc" : "original_title.asc"
    case .releaseDate:
      return mediaType == "tv" ? "first_air_date.desc" : "primary_release_date.desc"
    case .rating:
      return "vote_average.desc"
    }
  }
}
