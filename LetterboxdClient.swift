import Foundation

@MainActor
final class LetterboxdClient {
  static let shared = LetterboxdClient()

  private var cache: [Int: Double] = [:]
  private let session: URLSession

  private init() {
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(
      memoryCapacity: 10 * 1024 * 1024,
      diskCapacity: 50 * 1024 * 1024
    )
    config.requestCachePolicy = .returnCacheDataElseLoad
    self.session = URLSession(configuration: config)
  }

  func fetchAverageRating(tmdbId: Int, mediaType: String) async -> Double? {
    guard mediaType == "movie" else { return nil }

    if let cached = cache[tmdbId] {
      return cached
    }

    guard let url = URL(string: "https://letterboxd.com/tmdb/\(tmdbId)/") else {
      return nil
    }

    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent"
    )
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

    do {
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode),
        let html = String(data: data, encoding: .utf8)
      else {
        return nil
      }

      guard let rating = Self.parseAverageRating(from: html) else {
        return nil
      }

      cache[tmdbId] = rating
      return rating
    } catch {
      print("Letterboxd rating fetch failed for TMDB \(tmdbId): \(error)")
      return nil
    }
  }

  static func parseAverageRating(from html: String) -> Double? {
    if let rating = firstMatch(
      in: html,
      pattern: #"<meta\s+name="twitter:label2"\s+content="Average rating"\s*>\s*<meta\s+name="twitter:data2"\s+content="([0-9]+(?:\.[0-9]+)?)\s+out of 5""#
    ) {
      return Double(rating)
    }

    if let rating = firstMatch(
      in: html,
      pattern: #""aggregateRating"\s*:\s*\{[^}]*"ratingValue"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#
    ) {
      return Double(rating)
    }

    if let rating = firstMatch(
      in: html,
      pattern: #""ratingValue"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#
    ) {
      return Double(rating)
    }

    return nil
  }

  private static func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    else {
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
}
