import Foundation

struct LetterboxdImportEntry: Identifiable, Hashable {
  var id: String { slug }

  let title: String
  let year: Int?
  let slug: String
  var tmdbId: Int?
  var importRank: Int?
  var flickRankOrder: Int?
  let url: String
  var reviewPath: String?
  var isWatched: Bool
  var isWatchlist: Bool
  var isFavorite: Bool
  var rating: Double?
  var reviewText: String?
  var watchedDate: Date?
}

struct LetterboxdSyncSummary: Equatable {
  var imported = 0
  var updated = 0
  var skipped = 0
  var failed = 0

  var totalHandled: Int {
    imported + updated + skipped + failed
  }
}
