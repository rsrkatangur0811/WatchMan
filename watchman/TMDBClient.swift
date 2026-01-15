import Foundation

@MainActor
final class TMDBClient {
  static let shared = TMDBClient()

  private let baseURL: String
  private let apiKey: String
  private var cache: [String: Any] = [:]
  private let session: URLSession  // Custom session with HTTP caching

  private init() {
    self.baseURL = APIConfig.shared?.tmdbBaseURL ?? ""
    self.apiKey = APIConfig.shared?.tmdbAPIKey ?? ""

    // Configure URLSession with generous caching
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(
      memoryCapacity: 50 * 1024 * 1024,  // 50MB memory
      diskCapacity: 200 * 1024 * 1024  // 200MB disk
    )
    config.requestCachePolicy = .returnCacheDataElseLoad
    self.session = URLSession(configuration: config)
  }

  // MARK: - Cache Management

  private func cacheKey(for endpoint: String, id: Int) -> String {
    "\(endpoint)_\(id)"
  }

  func clearCache() {
    cache.removeAll()
  }

  // MARK: - Combined Title Fetch (Mega-call)

  /// Fetches title with all appended data in a single API call
  func fetchFullTitle(id: Int, mediaType: String) async throws -> TitleDetailResponse {
    let cacheKey = cacheKey(for: "fullTitle_\(mediaType)", id: id)

    if let cached = cache[cacheKey] as? TitleDetailResponse {
      return cached
    }

    // Build append_to_response based on media type
    var appendParams = "credits,images,videos,recommendations,reviews,watch/providers"
    if mediaType == "movie" {
      appendParams += ",release_dates"
    } else {
      appendParams += ",content_ratings"
    }

    let urlString =
      "\(baseURL)/3/\(mediaType)/\(id)?api_key=\(apiKey)&append_to_response=\(appendParams)&include_image_language=en,null"

    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: TitleDetailResponse = try await fetchAndDecode(url: url)
    cache[cacheKey] = response
    return response
  }

  // MARK: - Director Credits (Secondary call)

  func fetchDirectorCredits(personId: Int) async throws -> [Title] {
    let cacheKey = cacheKey(for: "directorCredits", id: personId)

    if let cached = cache[cacheKey] as? [Title] {
      return cached
    }

    let urlString = "\(baseURL)/3/person/\(personId)/combined_credits?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    struct CombinedCreditsResponse: Decodable {
      let cast: [Title]?
      let crew: [Title]?
    }

    let response: CombinedCreditsResponse = try await fetchAndDecode(url: url)

    // Combine and dedupe
    var uniqueTitles: [Int: Title] = [:]
    for title in (response.cast ?? []) + (response.crew ?? []) {
      if let id = title.id, uniqueTitles[id] == nil {
        uniqueTitles[id] = title
      }
    }

    let sorted = Array(uniqueTitles.values)
      .filter { $0.posterPath != nil }
      .sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }

    cache[cacheKey] = sorted
    return sorted
  }

  // MARK: - Collection Details

  func fetchCollectionDetails(id: Int) async throws -> [Title] {
    let cacheKey = cacheKey(for: "collection", id: id)

    if let cached = cache[cacheKey] as? [Title] {
      return cached
    }

    let urlString = "\(baseURL)/3/collection/\(id)?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    struct CollectionResponse: Decodable {
      let parts: [Title]
    }

    let response: CollectionResponse = try await fetchAndDecode(url: url)
    
    // Sort by release date
    let sorted = response.parts
      .filter { $0.posterPath != nil }
      .sorted { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }

    cache[cacheKey] = sorted
    return sorted
  }

  // MARK: - Season Details (On-demand)

  func fetchSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> (
    episodes: [Title.Episode], cast: [Cast]
  ) {
    let cacheKey = "season_\(tvId)_\(seasonNumber)"

    if let cached = cache[cacheKey] as? SeasonDetailResponse {
      return (cached.episodes ?? [], cached.credits?.cast ?? [])
    }

    let urlString =
      "\(baseURL)/3/tv/\(tvId)/season/\(seasonNumber)?api_key=\(apiKey)&append_to_response=credits"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: SeasonDetailResponse = try await fetchAndDecode(url: url)
    cache[cacheKey] = response
    return (response.episodes ?? [], response.credits?.cast ?? [])
  }

  // MARK: - Episode Details

  func fetchEpisodeDetails(tvId: Int, seasonNumber: Int, episodeNumber: Int) async throws
    -> Title.Episode
  {
    let cacheKey = "episode_\(tvId)_S\(seasonNumber)E\(episodeNumber)"

    if let cached = cache[cacheKey] as? Title.Episode {
      return cached
    }

    let urlString =
      "\(baseURL)/3/tv/\(tvId)/season/\(seasonNumber)/episode/\(episodeNumber)?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: Title.Episode = try await fetchAndDecode(url: url)
    cache[cacheKey] = response
    return response
  }

  // MARK: - Configuration Data (Countries/Languages)

  struct Country: Decodable, Identifiable {
    let iso_3166_1: String
    let english_name: String
    let native_name: String
    var id: String { iso_3166_1 }
  }

  struct Language: Decodable, Identifiable {
    let iso_639_1: String
    let english_name: String
    let name: String
    var id: String { iso_639_1 }
  }

  func fetchCountries() async throws -> [Country] {
    let cacheKey = "config_countries"
    if let cached = cache[cacheKey] as? [Country] { return cached }

    let urlString = "\(baseURL)/3/configuration/countries?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    let response: [Country] = try await fetchAndDecode(
      url: url, keyDecodingStrategy: .useDefaultKeys)
    // Sort alphabetically by English name
    let sorted = response.sorted { $0.english_name < $1.english_name }
    cache[cacheKey] = sorted
    return sorted
  }

  func fetchLanguages() async throws -> [Language] {
    let cacheKey = "config_languages"
    if let cached = cache[cacheKey] as? [Language] { return cached }

    let urlString = "\(baseURL)/3/configuration/languages?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    let response: [Language] = try await fetchAndDecode(
      url: url, keyDecodingStrategy: .useDefaultKeys)
    // Sort alphabetically by English name
    let sorted = response.sorted { $0.english_name < $1.english_name }
    cache[cacheKey] = sorted
    return sorted
  }

  // MARK: - Prefetch (Fire-and-Forget)

  /// Prefetches title data in background so cache is populated before navigation.
  /// Call this when user TAPS a title, then navigate after a brief delay.
  func prefetchTitle(id: Int, mediaType: String) {
    Task {
      // Check if already cached
      let cacheKey = self.cacheKey(for: "fullTitle_\(mediaType)", id: id)
      if cache[cacheKey] != nil { return }

      // Start loading in background (result goes to cache)
      _ = try? await fetchFullTitle(id: id, mediaType: mediaType)
    }
  }

  // MARK: - Network Helper

  private func fetchAndDecode<T: Decodable>(
    url: URL, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
  ) async throws -> T {
    let (data, urlResponse) = try await session.data(from: url)

    guard let response = urlResponse as? HTTPURLResponse else {
      throw NetworkError.badURLResponse(
        underlyingError: NSError(
          domain: "TMDBClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
        ))
    }

    switch response.statusCode {
    case 200:
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = keyDecodingStrategy
      do {
        return try decoder.decode(T.self, from: data)
      } catch let DecodingError.keyNotFound(key, context) {
        print("❌ Decoding Error - Key '\(key.stringValue)' not found: \(context.debugDescription)")
        print(
          "   codingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        throw NetworkError.badURLResponse(
          underlyingError: NSError(
            domain: "Decoding", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Missing key: \(key.stringValue)"]))
      } catch let DecodingError.typeMismatch(type, context) {
        print("❌ Decoding Error - Type mismatch for \(type): \(context.debugDescription)")
        print(
          "   codingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        throw NetworkError.badURLResponse(
          underlyingError: NSError(
            domain: "Decoding", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Type mismatch: \(type)"]))
      } catch let DecodingError.valueNotFound(type, context) {
        print("❌ Decoding Error - Value not found for \(type): \(context.debugDescription)")
        print(
          "   codingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        throw NetworkError.badURLResponse(
          underlyingError: NSError(
            domain: "Decoding", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Value not found: \(type)"]))
      } catch {
        print("❌ Decoding Error: \(error)")
        throw error
      }
    case 404:
      throw NetworkError.notFound
    case 429:
      throw NetworkError.rateLimited
    default:
      throw NetworkError.badURLResponse(
        underlyingError: NSError(
          domain: "TMDBClient", code: response.statusCode,
          userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.statusCode)"]
        ))
    }
  }
}

// MARK: - Extended Network Errors

extension NetworkError {
  static var notFound: NetworkError {
    .badURLResponse(
      underlyingError: NSError(
        domain: "TMDB", code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Resource not found"]
      ))
  }

  static var rateLimited: NetworkError {
    .badURLResponse(
      underlyingError: NSError(
        domain: "TMDB", code: 429,
        userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded. Please try again later."]
      ))
  }
}
