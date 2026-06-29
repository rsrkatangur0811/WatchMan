import Foundation
import SwiftData

@Model
final class WatchedEpisode {
  // MARK: - Properties

  /// TMDB TV show ID
  var showId: Int

  /// Season number (1-indexed)
  var seasonNumber: Int

  /// Episode number (1-indexed)
  var episodeNumber: Int

  /// Episode name/title
  var episodeName: String?

  /// Episode still image path (from TMDB)
  var stillPath: String?

  /// When the episode was marked as watched
  var watchedAt: Date

  // MARK: - Initialization

  init(
    showId: Int, seasonNumber: Int, episodeNumber: Int, episodeName: String? = nil,
    stillPath: String? = nil
  ) {
    self.showId = showId
    self.seasonNumber = seasonNumber
    self.episodeNumber = episodeNumber
    self.episodeName = episodeName
    self.stillPath = stillPath
    self.watchedAt = Date()
  }

  // MARK: - Computed Properties

  /// Unique identifier for this episode
  var uniqueId: String {
    "\(showId)_S\(seasonNumber)E\(episodeNumber)"
  }

  /// URL for the episode still image
  var stillURL: URL? {
    guard let stillPath, !stillPath.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w300\(stillPath)")
  }
}
