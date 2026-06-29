import Foundation
import Combine
import SwiftData

@MainActor
final class LetterboxdSyncService: ObservableObject {
  static let shared = LetterboxdSyncService()

  private struct MatchedEntry {
    let entry: LetterboxdImportEntry
    let title: Title
  }

  @Published var isSyncing = false
  @Published var progressMessage = ""
  @Published var summary = LetterboxdSyncSummary()
  @Published var errorMessage: String?

  private let client = LetterboxdSyncClient()
  private let dataFetcher = DataFetcher()
  private var modelContext: ModelContext?
  private var runningTask: Task<Void, Never>?
  private let tmdbCacheKey = "letterboxd.tmdbIdCache"

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  func startSync(username rawUsername: String) {
    guard runningTask == nil, !isSyncing else { return }

    runningTask = Task { [weak self] in
      await self?.performSync(username: rawUsername)
      await MainActor.run {
        self?.runningTask = nil
      }
    }
  }

  func sync(username rawUsername: String) async {
    guard !isSyncing else { return }
    await performSync(username: rawUsername)
  }

  func cancelSync() {
    runningTask?.cancel()
    runningTask = nil
    isSyncing = false
    progressMessage = "Sync cancelled"
  }

  private func performSync(username rawUsername: String) async {
    let username = normalizedUsername(rawUsername)
    guard !username.isEmpty else {
      errorMessage = "Enter a Letterboxd username."
      return
    }

    isSyncing = true
    errorMessage = nil
    summary = LetterboxdSyncSummary()
    defer { isSyncing = false }

    do {
      progressMessage = "Connecting to Letterboxd"
      let entries = try await client.fetchImportEntries(
        username: username,
        cachedTMDBIDs: cachedTMDBIDs()
      ) { [weak self] message in
        self?.progressMessage = message
      }
      saveCachedTMDBIDs(from: entries)

      progressMessage = "Matching films"
      for (index, entry) in entries.enumerated() {
        try Task.checkCancellation()
        progressMessage = "Matching \(index + 1) of \(entries.count)"
        do {
          guard let title = try await match(entry: entry) else {
            summary.failed += 1
            continue
          }

          importEntry(MatchedEntry(entry: entry, title: title))
        } catch {
          summary.failed += 1
        }
      }

      UserDefaults.standard.set(username, forKey: "letterboxd.username")
      UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "letterboxd.lastSync")
      progressMessage = "Sync complete"
    } catch is CancellationError {
      progressMessage = "Sync cancelled"
    } catch {
      errorMessage = error.localizedDescription
      progressMessage = "Sync failed"
    }
  }

  func undoImport() {
    guard let modelContext else { return }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { item in
        item.importedSource == "letterboxd"
      }
    )

    guard let items = try? modelContext.fetch(descriptor) else { return }
    for item in items {
      if item.letterboxdCreatedItem {
        modelContext.delete(item)
      } else {
        if let originalWatchlist = item.letterboxdOriginalIsWatchlist {
          item.isWatchlist = originalWatchlist
        }
        if let originalWatched = item.letterboxdOriginalIsWatched {
          item.isWatched = originalWatched
        }
        item.userRating = item.letterboxdOriginalRating
        clearLetterboxdMetadata(on: item)
      }
    }

    UserDefaults.standard.removeObject(forKey: "letterboxd.username")
    UserDefaults.standard.removeObject(forKey: "letterboxd.lastSync")
    UserDefaults.standard.removeObject(forKey: tmdbCacheKey)
    summary = LetterboxdSyncSummary()
    progressMessage = "Letterboxd import removed"
  }

  private func match(entry: LetterboxdImportEntry) async throws -> Title? {
    if let tmdbId = entry.tmdbId {
      if let existing = existingItem(titleId: tmdbId) {
        return Title(
          id: existing.titleId,
          title: existing.mediaType == "movie" ? existing.titleName : nil,
          name: existing.mediaType == "tv" ? existing.titleName : nil,
          posterPath: existing.posterPath,
          voteAverage: existing.userRating
        )
      }

      do {
        let dto = try await dataFetcher.fetchTitleDetailsDTO(for: "movie", id: tmdbId)
        return Title(dto: dto)
      } catch {
        // Fall through to title search when TMDB detail lookup is temporarily unavailable.
      }
    }

    let results = try await dataFetcher.fetchTitlesDTO(
      for: "movie",
      by: "search",
      with: entry.title
    )
    let candidates = results.map { Title(dto: $0) }
      .filter { $0.id != nil && $0.title != nil }

    if let year = entry.year {
      let yearMatches = candidates.filter { title in
        guard let releaseDate = title.releaseDate else { return false }
        return releaseDate.hasPrefix(String(year))
          && normalized(title.title ?? "") == normalized(entry.title)
      }
      if yearMatches.count == 1 {
        return yearMatches[0]
      }

      let sameYear = candidates.filter { title in
        title.releaseDate?.hasPrefix(String(year)) == true
      }
      if sameYear.count == 1 {
        return sameYear[0]
      }
    }

    let exact = candidates.filter { normalized($0.title ?? "") == normalized(entry.title) }
    return exact.count == 1 ? exact[0] : nil
  }

  private func existingItem(titleId: Int) -> UserLibraryItem? {
    guard let modelContext else { return nil }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { item in
        item.titleId == titleId && item.mediaType == "movie"
      }
    )
    return try? modelContext.fetch(descriptor).first
  }

  private func importEntry(_ matched: MatchedEntry) {
    guard let modelContext = modelContext,
      let titleId = matched.title.id
    else {
      summary.failed += 1
      return
    }

    let descriptor = FetchDescriptor<UserLibraryItem>(
      predicate: #Predicate { item in
        item.titleId == titleId && item.mediaType == "movie"
      }
    )

    let existing = try? modelContext.fetch(descriptor).first
    let item: UserLibraryItem
    let created: Bool
    if let existing {
      item = existing
      created = false
      summary.updated += 1
    } else {
      item = UserLibraryItem(
        titleId: titleId,
        mediaType: "movie",
        posterPath: matched.title.posterPath,
        titleName: matched.title.title ?? matched.entry.title
      )
      item.letterboxdCreatedItem = true
      modelContext.insert(item)
      created = true
      summary.imported += 1
    }

    if !created && item.importedSource != "letterboxd" {
      item.letterboxdOriginalIsWatchlist = item.isWatchlist
      item.letterboxdOriginalIsWatched = item.isWatched
      item.letterboxdOriginalRating = item.userRating
    }

    apply(matched.entry, to: item)
  }

  private func apply(_ entry: LetterboxdImportEntry, to item: UserLibraryItem) {
    item.importedSource = "letterboxd"
    item.letterboxdSlug = entry.slug
    item.letterboxdURL = entry.url
    item.letterboxdImportRank = entry.importRank
    item.flickRankOrder = entry.flickRankOrder
    item.letterboxdRating = entry.rating
    item.letterboxdReview = entry.reviewText
    item.letterboxdWatchedDate = entry.watchedDate
    item.isLetterboxdFavorite = entry.isFavorite
    item.letterboxdLastSyncedAt = Date()

    if entry.isWatched || entry.rating != nil || entry.reviewText != nil {
      item.isWatched = true
      item.isWatchlist = false
    } else if entry.isWatchlist && !item.isWatched {
      item.isWatchlist = true
    }

    if item.userRating == nil, let rating = entry.rating {
      item.userRating = rating
    }

    item.modifiedAt = Date()
  }

  private func clearLetterboxdMetadata(on item: UserLibraryItem) {
    item.importedSource = nil
    item.letterboxdSlug = nil
    item.letterboxdURL = nil
    item.letterboxdImportRank = nil
    item.flickRankOrder = nil
    item.letterboxdRating = nil
    item.letterboxdReview = nil
    item.letterboxdWatchedDate = nil
    item.isLetterboxdFavorite = false
    item.letterboxdLastSyncedAt = nil
    item.letterboxdCreatedItem = false
    item.letterboxdOriginalIsWatchlist = nil
    item.letterboxdOriginalIsWatched = nil
    item.letterboxdOriginalRating = nil
    item.modifiedAt = Date()
  }

  private func normalized(_ value: String) -> String {
    value
      .lowercased()
      .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
  }

  private func normalizedUsername(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed),
      let host = url.host,
      host.contains("letterboxd.com")
    {
      return url.pathComponents.dropFirst().first ?? ""
    }

    return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "@/"))
  }

  private func cachedTMDBIDs() -> [String: Int] {
    var cache: [String: Int] = [:]

    if let data = UserDefaults.standard.data(forKey: tmdbCacheKey),
      let stored = try? JSONDecoder().decode([String: Int].self, from: data)
    {
      cache.merge(stored) { current, _ in current }
    }

    if let modelContext {
      let descriptor = FetchDescriptor<UserLibraryItem>(
        predicate: #Predicate { item in
          item.importedSource == "letterboxd"
        }
      )
      if let items = try? modelContext.fetch(descriptor) {
        for item in items {
          guard let slug = item.letterboxdSlug else { continue }
          cache[slug] = item.titleId
        }
      }
    }

    return cache
  }

  private func saveCachedTMDBIDs(from entries: [LetterboxdImportEntry]) {
    var cache = cachedTMDBIDs()
    for entry in entries {
      guard let tmdbId = entry.tmdbId else { continue }
      cache[entry.slug] = tmdbId
    }

    if let data = try? JSONEncoder().encode(cache) {
      UserDefaults.standard.set(data, forKey: tmdbCacheKey)
    }
  }
}
