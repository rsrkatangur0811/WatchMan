import Foundation

@MainActor
final class RottenTomatoesClient {
  struct Scores {
    let critics: Int?
    let audience: Int?
  }

  static let shared = RottenTomatoesClient()

  private var cache: [URL: Scores] = [:]
  private let session: URLSession

  private init() {
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(
      memoryCapacity: 10 * 1024 * 1024,
      diskCapacity: 50 * 1024 * 1024
    )
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 30
    config.httpMaximumConnectionsPerHost = 20
    self.session = URLSession(configuration: config)
  }

  func fetchScores(url: URL) async -> Scores? {
    if let cached = cache[url] {
      return cached
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

      let scores = Self.parseScores(from: html)
      guard scores.critics != nil || scores.audience != nil else {
        return nil
      }

      cache[url] = scores
      return scores
    } catch {
      print("Rotten Tomatoes score fetch failed for \(url): \(error)")
      return nil
    }
  }

  static func parseScores(from html: String) -> Scores {
    if let json = firstMatch(
      in: html,
      pattern: #"<script[^>]*id="media-scorecard-json"[^>]*>\s*(\{.*?\})\s*</script>"#,
      options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) {
      let scores = parseScorecardJSON(json)
      if scores.critics != nil || scores.audience != nil {
        return scores
      }
    }

    return Scores(
      critics: intMatch(in: html, pattern: #""criticsScore"\s*:\s*\{[^}]*"score"\s*:\s*"([0-9]+)""#),
      audience: intMatch(in: html, pattern: #""audienceScore"\s*:\s*\{[^}]*"score"\s*:\s*"([0-9]+)""#)
    )
  }

  private static func parseScorecardJSON(_ json: String) -> Scores {
    struct Scorecard: Decodable {
      let audienceScore: Score?
      let criticsScore: Score?

      struct Score: Decodable {
        let score: String?
      }
    }

    guard let data = json.data(using: .utf8),
      let scorecard = try? JSONDecoder().decode(Scorecard.self, from: data)
    else {
      return Scores(critics: nil, audience: nil)
    }

    return Scores(
      critics: scorecard.criticsScore?.score.flatMap(Int.init),
      audience: scorecard.audienceScore?.score.flatMap(Int.init)
    )
  }

  private static func intMatch(in text: String, pattern: String) -> Int? {
    firstMatch(in: text, pattern: pattern).flatMap(Int.init)
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
}
