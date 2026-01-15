import Foundation
import SwiftData

@Model
final class UserLibraryItem {
  // MARK: - Properties

  /// TMDB title ID
  var titleId: Int

  /// Media type: "movie" or "tv"
  var mediaType: String

  /// Poster path for display
  var posterPath: String?

  /// Title name for display
  var titleName: String

  /// Whether this title is in the watchlist
  var isWatchlist: Bool = false

  /// Whether this title has been watched
  var isWatched: Bool = false

  /// User's rating (1-10), nil if not rated
  var userRating: Double?

  /// Date when this item was first added
  var addedAt: Date

  /// Date when last modified
  var modifiedAt: Date

  // MARK: - Initialization

  init(
    titleId: Int,
    mediaType: String,
    posterPath: String?,
    titleName: String,
    isWatchlist: Bool = false,
    isWatched: Bool = false,
    userRating: Double? = nil
  ) {
    self.titleId = titleId
    self.mediaType = mediaType
    self.posterPath = posterPath
    self.titleName = titleName
    self.isWatchlist = isWatchlist
    self.isWatched = isWatched
    self.userRating = userRating
    self.addedAt = Date()
    self.modifiedAt = Date()
  }

  // MARK: - Computed Properties

  var posterURL: URL? {
    guard let posterPath, !posterPath.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
  }

  var isRated: Bool {
    userRating != nil
  }

  /// Unique identifier combining titleId and mediaType
  var uniqueId: String {
    "\(mediaType)_\(titleId)"
  }
}
