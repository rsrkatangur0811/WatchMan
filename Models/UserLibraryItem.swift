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

  /// External source that imported this item, currently "letterboxd"
  var importedSource: String?

  /// Letterboxd film slug (e.g. "the-matrix")
  var letterboxdSlug: String?

  /// Public Letterboxd URL for the film or user's review entry
  var letterboxdURL: String?

  /// Position from the imported Letterboxd film list, used as the source ranking tie-breaker
  var letterboxdImportRank: Int?

  /// Strict Flick-style ranking position when imported from a real ordered ranking source
  var flickRankOrder: Int?

  /// Imported Letterboxd rating converted to Watchman's 1-10 scale
  var letterboxdRating: Double?

  /// Imported public Letterboxd review text, when visible
  var letterboxdReview: String?

  /// Public watched date imported from Letterboxd diary/review pages
  var letterboxdWatchedDate: Date?

  /// Whether this film is one of the user's public Letterboxd favorites
  var isLetterboxdFavorite: Bool = false

  /// Last time this item was touched by Letterboxd sync
  var letterboxdLastSyncedAt: Date?

  /// True when this local item was created by Letterboxd sync
  var letterboxdCreatedItem: Bool = false

  /// Original local state captured before first Letterboxd import touch
  var letterboxdOriginalIsWatchlist: Bool?
  var letterboxdOriginalIsWatched: Bool?
  var letterboxdOriginalRating: Double?

  /// Lightweight metadata persisted for local filtering, taste analysis, and sync enrichment.
  var releaseYear: Int?
  var genreIdsCSV: String?
  var directorNamesCSV: String?
  var runtime: Int?
  var metadataHydratedAt: Date?

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

  var genreIds: [Int] {
    get {
      (genreIdsCSV ?? "")
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    set {
      genreIdsCSV = newValue.map(String.init).joined(separator: ",")
    }
  }

  var directorNames: [String] {
    get {
      (directorNamesCSV ?? "")
        .split(separator: "|")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
    set {
      directorNamesCSV = newValue
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "|")
    }
  }

  /// Unique identifier combining titleId and mediaType
  var uniqueId: String {
    "\(mediaType)_\(titleId)"
  }
}
