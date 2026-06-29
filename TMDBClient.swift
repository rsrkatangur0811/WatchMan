import Foundation

@MainActor
final class TMDBClient {
  static let shared = TMDBClient()

  private let baseURL: String
  private let apiKey: String
  private var cache: [String: Any] = [:]
  private let session: URLSession  // Custom session with HTTP caching

  private init() {
    if let config = APIConfig.shared, (try? config.tmdbBase) != nil {
      self.baseURL = config.tmdbBaseURL
      self.apiKey = config.tmdbAPIKey
    } else {
      self.baseURL = ""
      self.apiKey = ""
    }

    // Configure URLSession with generous caching
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(
      memoryCapacity: 50 * 1024 * 1024,  // 50MB memory
      diskCapacity: 200 * 1024 * 1024  // 200MB disk
    )
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 30
    config.httpMaximumConnectionsPerHost = 20
    self.session = URLSession(configuration: config)
  }

  // MARK: - Cache Management

  private func cacheKey(for endpoint: String, id: Int) -> String {
    "\(endpoint)_\(id)"
  }

  private func ensureConfigured() throws {
    guard !baseURL.isEmpty, !apiKey.isEmpty else {
      throw NetworkError.missingConfig
    }
  }

  func clearCache() {
    cache.removeAll()
  }

  // MARK: - Combined Title Fetch (Mega-call)

  /// Fetches title with all appended data in a single API call
  func fetchFullTitle(id: Int, mediaType: String) async throws -> TitleDetailResponse {
    try ensureConfigured()
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

  // MARK: - External IDs (for OMDB lookup)

  struct ExternalIDs: Decodable {
    let imdbId: String?
    let facebookId: String?
    let instagramId: String?
    let twitterId: String?
  }

  /// Fetches external IDs (IMDB, Facebook, etc.) for a title
  func fetchExternalIDs(id: Int, mediaType: String) async throws -> ExternalIDs {
    try ensureConfigured()
    let cacheKey = "externalIds_\(mediaType)_\(id)"

    if let cached = cache[cacheKey] as? ExternalIDs {
      return cached
    }

    let urlString = "\(baseURL)/3/\(mediaType)/\(id)/external_ids?api_key=\(apiKey)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: ExternalIDs = try await fetchAndDecode(url: url)
    cache[cacheKey] = response
    return response
  }

  // MARK: - Textless Poster Fetch (Lightweight)
  
  /// Fetches only the images for a title and returns the best textless poster path
  func fetchTextlessPosterPath(id: Int, mediaType: String) async -> String? {
    let posterCacheKey = "textlessPoster_\(mediaType)_\(id)"
    
    // Check cache first
    if let cached = cache[posterCacheKey] as? String {
      return cached.isEmpty ? nil : cached
    }
    
    // Check if we already have full title data cached
    let fullCacheKey = cacheKey(for: "fullTitle_\(mediaType)", id: id)
    if let fullData = cache[fullCacheKey] as? TitleDetailResponse,
       let posters = fullData.images?.posters {
      let textless = extractBestTextlessPoster(from: posters)
      cache[posterCacheKey] = textless ?? ""
      return textless
    }
    
    // Fetch images only (lightweight call)
    let urlString = "\(baseURL)/3/\(mediaType)/\(id)/images?api_key=\(apiKey)&include_image_language=en,null"
    
    guard let url = URL(string: urlString) else { return nil }
    
    do {
      struct ImagesResponse: Decodable {
        let posters: [Title.ImageInfo]?
      }
      let response: ImagesResponse = try await fetchAndDecode(url: url)
      let textless = extractBestTextlessPoster(from: response.posters ?? [])
      cache[posterCacheKey] = textless ?? ""
      return textless
    } catch {
      print("Failed to fetch textless poster for \(mediaType)/\(id): \(error)")
      // Don't cache failures - allow retry on next launch
      return nil
    }
  }
  
  /// Extracts the best textless poster (null language, highest vote)
  private func extractBestTextlessPoster(from posters: [Title.ImageInfo]) -> String? {
    let textlessPosters = posters.filter { $0.iso6391 == nil }
    guard let best = textlessPosters.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) else {
      return nil
    }
    return best.filePath
  }
  
  // MARK: - Logo Fetch (Lightweight)
  
  /// Fetches only the images for a title and returns the best logo path
  func fetchLogoPath(id: Int, mediaType: String) async -> String? {
    let logoCacheKey = "logo_\(mediaType)_\(id)"
    
    // Check cache first
    if let cached = cache[logoCacheKey] as? String {
      return cached.isEmpty ? nil : cached
    }
    
    // Check if we already have full title data cached
    let fullCacheKey = cacheKey(for: "fullTitle_\(mediaType)", id: id)
    if let fullData = cache[fullCacheKey] as? TitleDetailResponse,
       let logos = fullData.images?.logos {
      let logo = extractBestLogo(from: logos)
      cache[logoCacheKey] = logo ?? ""
      return logo
    }
    
    // Fetch images only (lightweight call)
    let urlString = "\(baseURL)/3/\(mediaType)/\(id)/images?api_key=\(apiKey)&include_image_language=en,null"
    
    guard let url = URL(string: urlString) else { return nil }
    
    do {
      struct ImagesResponse: Decodable {
        let logos: [Title.ImageInfo]?
      }
      let response: ImagesResponse = try await fetchAndDecode(url: url)
      let logo = extractBestLogo(from: response.logos ?? [])
      cache[logoCacheKey] = logo ?? ""
      return logo
    } catch {
      print("Failed to fetch logo for \(mediaType)/\(id): \(error)")
      cache[logoCacheKey] = ""
      return nil
    }
  }
  
  /// Extracts the best logo (English or null, highest vote)
  private func extractBestLogo(from logos: [Title.ImageInfo]) -> String? {
    // 1. Prefer English logos
    let englishLogos = logos.filter { $0.iso6391 == "en" }
    if let bestEn = englishLogos.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
        return bestEn.filePath
    }
    
    // 2. Fallback to any logo (textless/null or other)
    if let bestAny = logos.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
        return bestAny.filePath
    }
    
    return nil
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

  // MARK: - List Fetching (Trending, Popular, Top Rated, etc.)

  /// Fetches a list of titles based on media type and list type
  func fetchTitles(
    mediaType: String,
    listType: String,
    page: Int = 1
  ) async throws -> [Title] {
    try ensureConfigured()
    let cacheKey = "titles_\(mediaType)_\(listType)_page_\(page)"

    if let cached = cache[cacheKey] as? [Title] {
      return cached
    }

    let path: String
    if listType == "trending" {
      let trendingMedia = mediaType == "multi" ? "all" : mediaType
      path = "3/trending/\(trendingMedia)/day"
    } else {
      path = "3/\(mediaType)/\(listType)"
    }

    let urlString = "\(baseURL)/\(path)?api_key=\(apiKey)&page=\(page)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    struct TMDBResponse: Decodable {
      let results: [Title]
    }

    let response: TMDBResponse = try await fetchAndDecode(url: url)
    let titles = response.results.map { title in
      var t = title
      // Ensure poster paths are full URLs
      if let posterPath = t.posterPath, !posterPath.isEmpty, !posterPath.contains("http") {
        let cleanPath = posterPath.hasPrefix("/") ? posterPath : "/\(posterPath)"
        t.posterPath = "https://image.tmdb.org/t/p/w500\(cleanPath)"
      }
      return t
    }

    cache[cacheKey] = titles
    return titles
  }

  /// Fetches titles using discover endpoint with advanced filters
  func fetchTitlesDTO(
    mediaType: String,
    listType: String,
    genreId: Int? = nil,
    keywords: String? = nil,
    excludeGenres: String? = nil,
    originalLanguage: String? = nil,
    originCountry: String? = nil,
    voteAverageMin: Double? = nil,
    voteCountMin: Int? = nil,
    voteCountMax: Int? = nil,
    releaseDateGte: String? = nil,
    releaseDateLte: String? = nil,
    runtimeLte: Int? = nil,
    sortBy: String? = nil,
    page: Int = 1
  ) async throws -> [TitleDTO] {
    try ensureConfigured()
    // Build cache key from parameters
    let cacheKey = "titlesDTO_\(mediaType)_\(listType)_g\(genreId ?? 0)_s\(sortBy ?? "default")_p\(page)"

    if let cached = cache[cacheKey] as? [TitleDTO] {
      return cached
    }

    var path: String
    if listType == "trending" {
      let trendingMedia = mediaType == "multi" ? "all" : mediaType
      path = "3/trending/\(trendingMedia)/day"
    } else if listType == "discover" {
      path = "3/discover/\(mediaType)"
    } else {
      path = "3/\(mediaType)/\(listType)"
    }

    guard let url = URL(string: "\(baseURL)/\(path)"),
          var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      throw NetworkError.urlBuildFailed
    }
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "page", value: String(page)),
    ]

    // Add sort parameter
    let sortOption = sortBy ?? "popularity.desc"
    queryItems.append(URLQueryItem(name: "sort_by", value: sortOption))

    // Add discover filters
    if listType == "discover" {
      if let genreId = genreId {
        queryItems.append(URLQueryItem(name: "with_genres", value: String(genreId)))
      }
      if let keywords = keywords {
        queryItems.append(URLQueryItem(name: "with_keywords", value: keywords))
      }
      if let excludeGenres = excludeGenres {
        queryItems.append(URLQueryItem(name: "without_genres", value: excludeGenres))
      }
      if let originalLanguage = originalLanguage {
        queryItems.append(URLQueryItem(name: "with_original_language", value: originalLanguage))
      }
      if let voteAverageMin = voteAverageMin {
        queryItems.append(URLQueryItem(name: "vote_average.gte", value: String(voteAverageMin)))
      }
      if let voteCountMin = voteCountMin {
        queryItems.append(URLQueryItem(name: "vote_count.gte", value: String(voteCountMin)))
      }
      if let voteCountMax = voteCountMax {
        queryItems.append(URLQueryItem(name: "vote_count.lte", value: String(voteCountMax)))
      }
      if let originCountry = originCountry {
        queryItems.append(URLQueryItem(name: "with_origin_country", value: originCountry))
      }
      if let releaseDateGte = releaseDateGte {
        let dateParam = mediaType == "movie" ? "primary_release_date.gte" : "first_air_date.gte"
        queryItems.append(URLQueryItem(name: dateParam, value: releaseDateGte))
      }
      if let releaseDateLte = releaseDateLte {
        let dateParam = mediaType == "movie" ? "primary_release_date.lte" : "first_air_date.lte"
        queryItems.append(URLQueryItem(name: dateParam, value: releaseDateLte))
      }
      if let runtimeLte = runtimeLte {
        queryItems.append(URLQueryItem(name: "with_runtime.lte", value: String(runtimeLte)))
      }
    }

    // Add year filter for year-based searches
    if listType != "discover" && listType != "trending" {
      // Year filtering handled by caller if needed
    }

    components.queryItems = queryItems
    guard let finalURL = components.url else {
      throw NetworkError.urlBuildFailed
    }

    struct TMDBResponse: Decodable {
      let results: [TitleDTO]
    }

    let response: TMDBResponse = try await fetchAndDecode(url: finalURL)
    var titles = response.results

    // Ensure poster paths are full URLs
    for i in titles.indices {
      if let path = titles[i].posterPath, !path.isEmpty, !path.contains("http") {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        titles[i].posterPath = "https://image.tmdb.org/t/p/w500\(cleanPath)"
      }
    }

    cache[cacheKey] = titles
    return titles
  }

  // MARK: - People

  struct PersonResponse: Decodable {
    let results: [Person]
  }

  /// Fetches trending people
  func fetchTrendingPeople(page: Int = 1) async throws -> [Person] {
    let cacheKey = "trendingPeople_\(page)"

    if let cached = cache[cacheKey] as? [Person] {
      return cached
    }

    let urlString = "\(baseURL)/3/person/popular?api_key=\(apiKey)&page=\(page)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: PersonResponse = try await fetchAndDecode(url: url)
    let filtered = response.results.filter { $0.profilePath != nil && !$0.name.isEmpty }

    cache[cacheKey] = filtered
    return filtered
  }

  /// Fetches people by search query
  func fetchSearchPeople(query: String, page: Int = 1) async throws -> [Person] {
    guard !query.isEmpty else { return [] }

    let cacheKey = "searchPeople_\(query)_\(page)"
    if let cached = cache[cacheKey] as? [Person] {
      return cached
    }

    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = "\(baseURL)/3/search/person?api_key=\(apiKey)&query=\(encodedQuery)&page=\(page)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    let response: PersonResponse = try await fetchAndDecode(url: url)
    let filtered = response.results.filter { $0.profilePath != nil && !$0.name.isEmpty }

    cache[cacheKey] = filtered
    return filtered
  }

  // MARK: - Search

  /// Searches for titles by query
  func searchTitles(query: String, mediaType: String, page: Int = 1) async throws -> [Title] {
    guard !query.isEmpty else { return [] }

    let cacheKey = "search_\(mediaType)_\(query)_\(page)"
    if let cached = cache[cacheKey] as? [Title] {
      return cached
    }

    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = "\(baseURL)/3/search/\(mediaType)?api_key=\(apiKey)&query=\(encodedQuery)&page=\(page)"
    guard let url = URL(string: urlString) else {
      throw NetworkError.urlBuildFailed
    }

    struct TMDBResponse: Decodable {
      let results: [Title]
    }

    let response: TMDBResponse = try await fetchAndDecode(url: url)
    let titles = response.results.map { title in
      var t = title
      if let posterPath = t.posterPath, !posterPath.isEmpty, !posterPath.contains("http") {
        let cleanPath = posterPath.hasPrefix("/") ? posterPath : "/\(posterPath)"
        t.posterPath = "https://image.tmdb.org/t/p/w500\(cleanPath)"
      }
      return t
    }

    cache[cacheKey] = titles
    return titles
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
