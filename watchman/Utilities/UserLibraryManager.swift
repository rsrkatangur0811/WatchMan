import Foundation
import SwiftData
import SwiftUI

@MainActor
class UserLibraryManager: ObservableObject {
  private var modelContext: ModelContext?

  // MARK: - Singleton
  static let shared = UserLibraryManager()

  private init() {}

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  // MARK: - Query Methods

  func getItem(titleId: Int, mediaType: String) -> UserLibraryItem? {
    guard let modelContext else { return nil }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { item in
        item.titleId == titleId && item.mediaType == mediaType
      }
    )

    return try? modelContext.fetch(descriptor).first
  }

  func getOrCreateItem(for title: Title) -> UserLibraryItem {
    let titleId = title.id ?? 0
    let mediaType = title.name != nil ? "tv" : "movie"

    if let existing = getItem(titleId: titleId, mediaType: mediaType) {
      // Update metadata if better information is available
      if let newPoster = title.posterPath, !newPoster.isEmpty, existing.posterPath != newPoster {
        existing.posterPath = newPoster
      }

      let newName = title.name ?? title.title ?? "Unknown"
      if existing.titleName != newName && newName != "Unknown" {
        existing.titleName = newName
      }

      return existing
    }

    let newItem = UserLibraryItem(
      titleId: titleId,
      mediaType: mediaType,
      posterPath: title.posterPath,
      titleName: title.name ?? title.title ?? "Unknown"
    )

    modelContext?.insert(newItem)
    return newItem
  }

  /// Ensures a TV show exists in the library (called when marking episodes watched)
  func ensureTVShowInLibrary(showId: Int, name: String, posterPath: String?) {
    guard let modelContext else { return }

    // Check if already exists
    if getItem(titleId: showId, mediaType: "tv") != nil {
      return
    }

    // Create new library item for the TV show
    let newItem = UserLibraryItem(
      titleId: showId,
      mediaType: "tv",
      posterPath: posterPath,
      titleName: name
    )

    modelContext.insert(newItem)
  }

  // MARK: - Watchlist

  func isInWatchlist(titleId: Int, mediaType: String) -> Bool {
    getItem(titleId: titleId, mediaType: mediaType)?.isWatchlist ?? false
  }

  func toggleWatchlist(for title: Title) {
    let item = getOrCreateItem(for: title)
    item.isWatchlist.toggle()
    item.modifiedAt = Date()

    // Clean up if no flags are set
    cleanupIfEmpty(item)
  }

  func getWatchlist() -> [UserLibraryItem] {
    guard let modelContext else { return [] }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { $0.isWatchlist },
      sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
    )

    return (try? modelContext.fetch(descriptor)) ?? []
  }

  // MARK: - Watched

  func isWatched(titleId: Int, mediaType: String) -> Bool {
    getItem(titleId: titleId, mediaType: mediaType)?.isWatched ?? false
  }

  func toggleWatched(for title: Title) {
    let item = getOrCreateItem(for: title)
    item.isWatched.toggle()
    item.modifiedAt = Date()

    // If marking as watched, remove from watchlist
    if item.isWatched {
      item.isWatchlist = false
    }

    cleanupIfEmpty(item)
  }

  func getWatched() -> [UserLibraryItem] {
    guard let modelContext else { return [] }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { $0.isWatched },
      sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
    )

    return (try? modelContext.fetch(descriptor)) ?? []
  }

  // MARK: - Ratings

  func getRating(titleId: Int, mediaType: String) -> Double? {
    getItem(titleId: titleId, mediaType: mediaType)?.userRating
  }

  func setRating(for title: Title, rating: Double?) {
    let item = getOrCreateItem(for: title)
    item.userRating = rating
    item.modifiedAt = Date()

    // If rated, it implies watched
    if rating != nil {
      item.isWatched = true
      item.isWatchlist = false
    }

    cleanupIfEmpty(item)
  }

  func getRated() -> [UserLibraryItem] {
    guard let modelContext else { return [] }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { $0.userRating != nil },
      sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
    )

    return (try? modelContext.fetch(descriptor)) ?? []
  }

  // MARK: - Cleanup

  /// Remove item if it has no flags or rating set
  private func cleanupIfEmpty(_ item: UserLibraryItem) {
    if !item.isWatchlist && !item.isWatched && item.userRating == nil {
      modelContext?.delete(item)
    }
  }

  // MARK: - Statistics

  func getStats() -> (watchlist: Int, watched: Int, rated: Int) {
    (
      watchlist: getWatchlist().count,
      watched: getWatched().count,
      rated: getRated().count
    )
  }

  // MARK: - Episode Watch Tracking

  func isEpisodeWatched(showId: Int, season: Int, episode: Int) -> Bool {
    guard let modelContext else { return false }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season && item.episodeNumber == episode
      }
    )

    return (try? modelContext.fetch(descriptor).first) != nil
  }

  func toggleEpisodeWatched(showId: Int, season: Int, episode: Int) {
    guard let modelContext else { return }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season && item.episodeNumber == episode
      }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      // Already watched, remove it
      modelContext.delete(existing)
    } else {
      // Not watched, add it
      let newEpisode = WatchedEpisode(showId: showId, seasonNumber: season, episodeNumber: episode)
      modelContext.insert(newEpisode)
    }
  }

  /// Marks an episode as watched (only adds, never removes)
  func markEpisodeWatched(
    showId: Int, season: Int, episode: Int, episodeName: String? = nil, stillPath: String? = nil
  ) {
    guard let modelContext else { return }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season && item.episodeNumber == episode
      }
    )

    // Only add if not already watched
    if (try? modelContext.fetch(descriptor).first) == nil {
      let newEpisode = WatchedEpisode(
        showId: showId,
        seasonNumber: season,
        episodeNumber: episode,
        episodeName: episodeName,
        stillPath: stillPath
      )
      modelContext.insert(newEpisode)
    }
  }

  /// Updates metadata for an existing watched episode
  func updateEpisodeMetadata(
    showId: Int, season: Int, episode: Int, name: String?, stillPath: String?
  ) {
    guard let modelContext else { return }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season && item.episodeNumber == episode
      }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      existing.episodeName = name
      existing.stillPath = stillPath
    }
  }

  /// Marks all episodes across all seasons as watched
  func markAllSeasonsWatched(showId: Int, seasons: [(seasonNumber: Int, episodeCount: Int)]) {
    for season in seasons {
      for episodeNum in 1...max(1, season.episodeCount) {
        markEpisodeWatched(showId: showId, season: season.seasonNumber, episode: episodeNum)
      }
    }
  }

  func markSeasonWatched(showId: Int, season: Int, episodeNumbers: [Int]) {
    guard let modelContext else { return }

    for episodeNum in episodeNumbers {
      let descriptor = FetchDescriptor<WatchedEpisode>(
        predicate: #Predicate { item in
          item.showId == showId && item.seasonNumber == season && item.episodeNumber == episodeNum
        }
      )

      // Only add if not already watched
      if (try? modelContext.fetch(descriptor).first) == nil {
        let newEpisode = WatchedEpisode(
          showId: showId, seasonNumber: season, episodeNumber: episodeNum)
        modelContext.insert(newEpisode)
      }
    }
  }

  func unmarkSeasonWatched(showId: Int, season: Int) {
    guard let modelContext else { return }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season
      }
    )

    if let episodes = try? modelContext.fetch(descriptor) {
      for episode in episodes {
        modelContext.delete(episode)
      }
    }
  }

  func getWatchedEpisodes(showId: Int, season: Int) -> [Int] {
    guard let modelContext else { return [] }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season
      },
      sortBy: [SortDescriptor(\.episodeNumber)]
    )

    return (try? modelContext.fetch(descriptor).map { $0.episodeNumber }) ?? []
  }

  func getShowProgress(showId: Int) -> Int {
    guard let modelContext else { return 0 }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId
      }
    )

    return (try? modelContext.fetch(descriptor).count) ?? 0
  }

  func getSeasonProgress(showId: Int, season: Int) -> Int {
    guard let modelContext else { return 0 }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId && item.seasonNumber == season
      }
    )

    return (try? modelContext.fetch(descriptor).count) ?? 0
  }

  /// Returns the latest watched episode for a show (season, episode)
  func getLatestWatchedEpisode(showId: Int) -> (season: Int, episode: Int)? {
    guard let modelContext else { return nil }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId
      },
      sortBy: [
        SortDescriptor(\.seasonNumber, order: .reverse),
        SortDescriptor(\.episodeNumber, order: .reverse),
      ]
    )

    guard let latest = try? modelContext.fetch(descriptor).first else { return nil }
    return (season: latest.seasonNumber, episode: latest.episodeNumber)
  }

  /// Returns the next episode to watch (season, episode) based on what's been watched
  func getNextEpisodeToWatch(showId: Int) -> (season: Int, episode: Int)? {
    guard let latest = getLatestWatchedEpisode(showId: showId) else { return nil }
    // Simply return the next episode number
    return (season: latest.season, episode: latest.episode + 1)
  }

  /// Returns full details of the latest watched episode including still image
  func getLatestWatchedEpisodeDetails(showId: Int) -> (
    season: Int, episode: Int, name: String?, stillURL: URL?
  )? {
    guard let modelContext else { return nil }

    let descriptor = FetchDescriptor<WatchedEpisode>(
      predicate: #Predicate { item in
        item.showId == showId
      },
      sortBy: [
        SortDescriptor(\.seasonNumber, order: .reverse),
        SortDescriptor(\.episodeNumber, order: .reverse),
      ]
    )

    guard let latest = try? modelContext.fetch(descriptor).first else { return nil }
    return (
      season: latest.seasonNumber,
      episode: latest.episodeNumber,
      name: latest.episodeName,
      stillURL: latest.stillURL
    )
  }
}
