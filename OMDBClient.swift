import Foundation

/// Client for fetching ratings from OMDB (Open Movie Database)
/// Provides real IMDB and Rotten Tomatoes scores
@MainActor
final class OMDBClient {
  static let shared = OMDBClient()

  private let config = APIConfig.shared
  private var cache: [String: OMDBResponse] = [:]
  private let session: URLSession

  private init() {
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

  // MARK: - Public API

  /// Fetches ratings from OMDB using an IMDB ID
  /// - Parameter imdbID: The IMDB ID (e.g., "tt1234567")
  /// - Returns: OMDBResponse with ratings, or nil if failed
  func fetchRatings(imdbID: String) async -> OMDBResponse? {
    // Check cache first
    if let cached = cache[imdbID] {
      return cached
    }

    guard !imdbID.isEmpty else { return nil }

    guard let config, config.hasOMDBConfig else { return nil }

    guard let baseURL = try? config.omdbBase,
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.queryItems = [
      URLQueryItem(name: "apikey", value: config.omdbAPIKey),
      URLQueryItem(name: "i", value: imdbID),
      URLQueryItem(name: "tomatoes", value: "true"),
    ]

    guard let url = components.url else { return nil }

    do {
      let (data, response) = try await session.data(from: url)

      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        print("OMDB: Bad response for \(imdbID)")
        return nil
      }

      let decoder = JSONDecoder()
      let omdbResponse = try decoder.decode(OMDBResponse.self, from: data)

      // Only cache successful responses
      if omdbResponse.response == "True" {
        cache[imdbID] = omdbResponse
      }

      return omdbResponse
    } catch {
      print("OMDB: Failed to fetch ratings for \(imdbID): \(error)")
      return nil
    }
  }

  func clearCache() {
    cache.removeAll()
  }
}

// MARK: - Response Models

struct OMDBRating: Decodable {
  let Source: String
  let Value: String
}

struct OMDBResponse: Decodable {
  let Response: String?
  let imdbRating: String?
  let imdbVotes: String?
  let Metascore: String?
  let Ratings: [OMDBRating]?
  let tomatoURL: String?

  var response: String? { Response }

  // MARK: - Parsed Values

  /// IMDB rating as a Double (e.g., 7.8)
  var imdbScore: Double? {
    guard let rating = imdbRating else { return nil }
    return Double(rating)
  }

  /// IMDB vote count as Int
  var imdbVoteCount: Int? {
    guard let votes = imdbVotes else { return nil }
    let cleaned = votes.replacingOccurrences(of: ",", with: "")
    return Int(cleaned)
  }

  /// Rotten Tomatoes Critics Score as percentage (e.g., 93)
  var rottenTomatoesCritics: Int? {
    guard let ratings = Ratings else { return nil }
    guard let rt = ratings.first(where: { $0.Source == "Rotten Tomatoes" }) else { return nil }
    // Value is like "93%"
    let cleaned = rt.Value.replacingOccurrences(of: "%", with: "")
    return Int(cleaned)
  }

  /// Metacritic Score (e.g., 81)
  var metacriticScore: Int? {
    guard let meta = Metascore else { return nil }
    return Int(meta)
  }
}
