import Foundation

enum LetterboxdSyncError: LocalizedError {
  case profileNotFound
  case blockedOrPrivate

  var errorDescription: String? {
    switch self {
    case .profileNotFound:
      return "Could not find that Letterboxd profile."
    case .blockedOrPrivate:
      return "Letterboxd blocked the request or the profile is not public."
    }
  }
}

final class LetterboxdSyncClient {
  private let baseURL = URL(string: "https://letterboxd.com")!
  private let session: URLSession

  init() {
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(
      memoryCapacity: 20 * 1024 * 1024,
      diskCapacity: 100 * 1024 * 1024
    )
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 30
    config.httpMaximumConnectionsPerHost = 20
    self.session = URLSession(configuration: config)
  }

  func validateProfile(username: String) async throws {
    let html = try await fetch(path: "/\(username)/")
    guard html.contains("screen-member-profile") || html.contains("profile-header") else {
      throw LetterboxdSyncError.profileNotFound
    }
  }

  func fetchImportEntries(
    username: String,
    cachedTMDBIDs: [String: Int] = [:],
    progress: @MainActor @escaping (String) -> Void
  ) async throws -> [LetterboxdImportEntry] {
    try await validateProfile(username: username)

    var entriesBySlug: [String: LetterboxdImportEntry] = [:]

    let watched = try await fetchPagedPosterEntries(
      initialPath: "/\(username)/films/",
      status: .watched,
      progressPrefix: "Watched",
      progress: progress
    )
    merge(rank(watched), into: &entriesBySlug)

    let rankedRatings = try await fetchPagedPosterEntries(
      initialPath: "/\(username)/films/ratings/by/entry-rating/",
      status: .watched,
      progressPrefix: "Ratings",
      progress: progress
    )
    merge(flickRank(rankedRatings), into: &entriesBySlug)

    let watchlist = try await fetchPagedPosterEntries(
      initialPath: "/\(username)/watchlist/",
      status: .watchlist,
      progressPrefix: "Watchlist",
      progress: progress
    )
    merge(watchlist, into: &entriesBySlug)

    let favorites = try await fetchFavorites(username: username)
    merge(favorites, into: &entriesBySlug)

    var entries = Array(entriesBySlug.values)
    entries = await hydrateMetadata(
      entries,
      cachedTMDBIDs: cachedTMDBIDs,
      progress: progress
    )

    return entries
  }

  private func hydrateMetadata(
    _ entries: [LetterboxdImportEntry],
    cachedTMDBIDs: [String: Int],
    progress: @MainActor @escaping (String) -> Void
  ) async -> [LetterboxdImportEntry] {
    guard !entries.isEmpty else { return [] }

    var hydrated = entries
    let batchSize = 5

    for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
      guard !Task.isCancelled else { break }
      let batchEnd = min(batchStart + batchSize, entries.count)
      await progress("Resolving \(batchEnd) of \(entries.count)")

      await withTaskGroup(of: (Int, Int?, String?, Date?).self) { group in
        for index in batchStart..<batchEnd {
          let entry = entries[index]
          group.addTask { [self] in
            guard !Task.isCancelled else {
              return (index, entry.tmdbId, nil, nil)
            }

            var tmdbId = entry.tmdbId ?? cachedTMDBIDs[entry.slug]
            if tmdbId == nil {
              do {
                let html = try await fetch(path: "/film/\(entry.slug)/")
                tmdbId = Self.tmdbId(fromFilmPage: html)
              } catch {
                // Title/year fallback remains available when the film page is blocked.
              }
            }

            guard let reviewPath = entry.reviewPath else {
              return (index, tmdbId, nil, nil)
            }

            do {
              let html = try await fetch(path: reviewPath)
              return (
                index,
                tmdbId,
                Self.reviewText(in: html),
                Self.watchedDate(in: html)
              )
            } catch {
              return (index, tmdbId, nil, nil)
            }
          }
        }

        for await result in group {
          hydrated[result.0].tmdbId = result.1
          hydrated[result.0].reviewText = result.2 ?? hydrated[result.0].reviewText
          hydrated[result.0].watchedDate = result.3 ?? hydrated[result.0].watchedDate
        }
      }
    }

    return hydrated
  }

  private enum EntryStatus {
    case watched
    case watchlist
    case favorite
  }

  private func rank(_ entries: [LetterboxdImportEntry]) -> [LetterboxdImportEntry] {
    entries.enumerated().map { index, entry in
      var ranked = entry
      ranked.importRank = index + 1
      return ranked
    }
  }

  private func flickRank(_ entries: [LetterboxdImportEntry]) -> [LetterboxdImportEntry] {
    entries.enumerated().map { index, entry in
      var ranked = entry
      ranked.flickRankOrder = index + 1
      return ranked
    }
  }

  private func fetchPagedPosterEntries(
    initialPath: String,
    status: EntryStatus,
    progressPrefix: String,
    progress: @MainActor @escaping (String) -> Void
  ) async throws -> [LetterboxdImportEntry] {
    var entries: [LetterboxdImportEntry] = []
    var path: String? = initialPath
    var page = 1

    while let currentPath = path {
      await progress("\(progressPrefix) page \(page)")
      let html = try await fetch(path: currentPath)
      let pageEntries = Self.parsePosterEntries(from: html, status: status)
      entries.append(contentsOf: pageEntries)
      path = Self.nextPagePath(from: html)
      page += 1
    }

    return entries
  }

  private func fetchFavorites(username: String) async throws -> [LetterboxdImportEntry] {
    let html = try await fetch(path: "/\(username)/")
    let favoritesHTML = Self.firstMatch(
      in: html,
      pattern: #"(<section id="favourites"[\s\S]*?</section>)"#,
      options: [.caseInsensitive]
    ) ?? ""
    return Self.parsePosterEntries(from: favoritesHTML, status: .favorite)
  }

  private func merge(
    _ entries: [LetterboxdImportEntry],
    into entriesBySlug: inout [String: LetterboxdImportEntry]
  ) {
    for entry in entries {
      if var existing = entriesBySlug[entry.slug] {
        existing.isWatched = existing.isWatched || entry.isWatched
        existing.isWatchlist = existing.isWatchlist || entry.isWatchlist
        existing.isFavorite = existing.isFavorite || entry.isFavorite
        existing.tmdbId = existing.tmdbId ?? entry.tmdbId
        if let incomingRank = entry.importRank {
          existing.importRank = min(existing.importRank ?? incomingRank, incomingRank)
        }
        if let incomingRank = entry.flickRankOrder {
          existing.flickRankOrder = min(existing.flickRankOrder ?? incomingRank, incomingRank)
        }
        existing.rating = existing.rating ?? entry.rating
        existing.reviewPath = existing.reviewPath ?? entry.reviewPath
        existing.reviewText = existing.reviewText ?? entry.reviewText
        existing.watchedDate = existing.watchedDate ?? entry.watchedDate
        entriesBySlug[entry.slug] = existing
      } else {
        entriesBySlug[entry.slug] = entry
      }
    }
  }

  private func fetch(path: String) async throws -> String {
    let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
    guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
      throw LetterboxdSyncError.profileNotFound
    }

    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent"
    )
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw LetterboxdSyncError.profileNotFound
    }

    if httpResponse.statusCode == 403 {
      throw LetterboxdSyncError.blockedOrPrivate
    }
    if httpResponse.statusCode == 404 {
      throw LetterboxdSyncError.profileNotFound
    }
    guard (200...299).contains(httpResponse.statusCode),
      let html = String(data: data, encoding: .utf8)
    else {
      throw LetterboxdSyncError.profileNotFound
    }

    return html
  }

  private static func parsePosterEntries(from html: String, status: EntryStatus) -> [LetterboxdImportEntry] {
    let pattern = #"<div class="react-component[^"]*"[^>]*data-component-class="LazyPoster"[^>]*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return []
    }

    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
    let matches = regex.matches(in: html, range: nsRange)
    var entries: [LetterboxdImportEntry] = []

    for (index, match) in matches.enumerated() {
      guard let start = Range(match.range, in: html) else { continue }
      let nextStart = index + 1 < matches.count
        ? Range(matches[index + 1].range, in: html)?.lowerBound
        : nil
      let segmentEnd = nextStart ?? html.index(start.upperBound, offsetBy: 2500, limitedBy: html.endIndex)
        ?? html.endIndex
      let segment = String(html[start.lowerBound..<segmentEnd])

      guard let title = attribute("data-item-name", in: segment),
        let slug = attribute("data-item-slug", in: segment)
      else {
        continue
      }

      let year = attribute("data-item-full-display-name", in: segment).flatMap(extractYear)
      var entry = LetterboxdImportEntry(
        title: htmlDecoded(title),
        year: year,
        slug: slug,
        tmdbId: nil,
        importRank: nil,
        flickRankOrder: nil,
        url: "https://letterboxd.com/film/\(slug)/",
        reviewPath: reviewPath(in: segment),
        isWatched: status == .watched,
        isWatchlist: status == .watchlist,
        isFavorite: status == .favorite,
        rating: rating(in: segment),
        reviewText: reviewText(in: segment),
        watchedDate: watchedDate(in: segment)
      )

      if status == .favorite {
        entry.isWatched = false
      }

      entries.append(entry)
    }

    return entries
  }

  private static func nextPagePath(from html: String) -> String? {
    firstMatch(in: html, pattern: #"<a class="next" href="([^"]+)""#)
  }

  private static func tmdbId(fromFilmPage html: String) -> Int? {
    firstMatch(in: html, pattern: #"data-tmdb-id="([0-9]+)""#).flatMap(Int.init)
  }

  private static func attribute(_ name: String, in text: String) -> String? {
    firstMatch(in: text, pattern: #"\#(name)="([^"]*)""#)
  }

  private static func rating(in text: String) -> Double? {
    guard let value = firstMatch(in: text, pattern: #"rated-([0-9]+)"#),
      let intValue = Int(value)
    else {
      return nil
    }
    return Double(intValue)
  }

  private static func watchedDate(in text: String) -> Date? {
    guard let dateString = firstMatch(in: text, pattern: #"<time[^>]*datetime="([0-9]{4}-[0-9]{2}-[0-9]{2})""#)
    else {
      return nil
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: dateString)
  }

  private static func reviewText(in text: String) -> String? {
    guard let raw = firstMatch(
      in: text,
      pattern: #"<div class="body-text[^"]*js-review-body[^"]*"[^>]*>\s*(.*?)\s*</div>"#,
      options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) ?? firstMatch(
      in: text,
      pattern: #"<p>(.*?)</p>"#,
      options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
      return nil
    }

    let noTags = raw.replacingOccurrences(
      of: #"<[^>]+>"#,
      with: " ",
      options: .regularExpression
    )
    let collapsed = htmlDecoded(noTags)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return collapsed.isEmpty ? nil : collapsed
  }

  private static func reviewPath(in text: String) -> String? {
    firstMatch(
      in: text,
      pattern: #"<a href="([^"]+)" class="review-micro"#
    ) ?? firstMatch(
      in: text,
      pattern: #"<a href="([^"]+)" class="review-micro[^"]*""#
    )
  }

  private static func extractYear(from text: String) -> Int? {
    guard let value = firstMatch(in: text, pattern: #"\(([0-9]{4})\)"#) else {
      return nil
    }
    return Int(value)
  }

  private static func firstMatch(
    in text: String,
    pattern: String,
    options: NSRegularExpression.Options = [.caseInsensitive]
  ) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
      match.numberOfRanges > 1,
      let matchRange = Range(match.range(at: 1), in: text)
    else {
      return nil
    }
    return String(text[matchRange])
  }

  private static func htmlDecoded(_ string: String) -> String {
    let replacements = [
      "&amp;": "&",
      "&quot;": "\"",
      "&#034;": "\"",
      "&#039;": "'",
      "&apos;": "'",
      "&nbsp;": " ",
      "&bull;": "•",
      "&lrm;": "",
      "&rsquo;": "'",
      "&lsquo;": "'",
      "&ldquo;": "\"",
      "&rdquo;": "\"",
    ]

    return replacements.reduce(string) { result, replacement in
      result.replacingOccurrences(of: replacement.key, with: replacement.value)
    }
  }
}
