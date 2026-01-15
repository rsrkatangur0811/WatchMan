import Foundation

struct DataFetcher {
  let tmdbBaseURL = APIConfig.shared?.tmdbBaseURL
  let tmdbAPIKey = APIConfig.shared?.tmdbAPIKey
  let youtubeSearchURL = APIConfig.shared?.youtubeSearchURL
  let youtubeAPIKey = APIConfig.shared?.youtubeAPIKey

  //https://api.themoviedb.org/3/trending/movie/day?api_key=YOUR_API_KEY
  //https://api.themoviedb.org/3/movie/top_rated?api_key=YOUR_API_KEY
  //https://api.themoviedb.org/3/movie/upcoming?api_key=YOUR_API_KEY
  //https://api.themoviedb.org/3/search/movie?api_key=YourKey&query=PulpFiction

  func fetchTitleDetails(for media: String, id: Int) async throws -> Title {
    let urlString =
      "\(tmdbBaseURL ?? "")/3/\(media)/\(id)?api_key=\(tmdbAPIKey ?? "")&append_to_response=images,release_dates,content_ratings&include_image_language=en,null"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    let title = try await fetchAndDecode(url: url, type: Title.self)
    // Ensure paths are full URLs if needed, but Title model usually expects partials.
    // Logic in View handles partials, so we keep as is.
    return title
  }

  func fetchWatchProviders(for media: String, id: Int) async throws -> ProviderResponse {
    let urlString =
      "\(tmdbBaseURL ?? "")/3/\(media)/\(id)/watch/providers?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: ProviderResponse.self)
  }

  func fetchCredits(for media: String, id: Int) async throws -> CreditsResponse {
    let urlString = "\(tmdbBaseURL ?? "")/3/\(media)/\(id)/credits?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: CreditsResponse.self)
  }

  func fetchReviews(for media: String, id: Int) async throws -> [Review] {
    let urlString = "\(tmdbBaseURL ?? "")/3/\(media)/\(id)/reviews?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: ReviewResponse.self).results
  }

  func fetchVideos(for media: String, id: Int) async throws -> [Video] {
    let urlString = "\(tmdbBaseURL ?? "")/3/\(media)/\(id)/videos?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: VideoResponse.self).results
  }

  func fetchRecommendations(for media: String, id: Int) async throws -> [Title] {
    let urlString =
      "\(tmdbBaseURL ?? "")/3/\(media)/\(id)/recommendations?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: TMDBAPIObject.self).results
  }

  // MARK: - Certification Endpoints

  struct ReleaseDatesResponse: Decodable {
    let results: [ReleaseDateCountry]

    struct ReleaseDateCountry: Decodable {
      let iso_3166_1: String
      let release_dates: [ReleaseDate]
    }

    struct ReleaseDate: Decodable {
      let certification: String
      let type: Int
    }
  }

  struct ContentRatingsResponse: Decodable {
    let results: [ContentRating]

    struct ContentRating: Decodable {
      let iso_3166_1: String
      let rating: String
    }
  }

  func fetchMovieCertification(id: Int) async throws -> String {
    let urlString = "\(tmdbBaseURL ?? "")/3/movie/\(id)/release_dates?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(ReleaseDatesResponse.self, from: data)

    // Prefer US certification
    if let us = response.results.first(where: { $0.iso_3166_1 == "US" }) {
      // Prefer Theatrical (3) or Digital (4)
      if let cert = us.release_dates.first(where: {
        ($0.type == 3 || $0.type == 4) && !$0.certification.isEmpty
      })?.certification {
        return cert
      }
      // Fallback to any US release with certification
      if let cert = us.release_dates.first(where: { !$0.certification.isEmpty })?.certification {
        return cert
      }
    }

    // Fallback to any region with certification
    for country in response.results {
      if let cert = country.release_dates.first(where: { !$0.certification.isEmpty })?.certification
      {
        return cert
      }
    }

    return "NR"
  }

  func fetchTVCertification(id: Int) async throws -> String {
    let urlString = "\(tmdbBaseURL ?? "")/3/tv/\(id)/content_ratings?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(ContentRatingsResponse.self, from: data)

    // Prefer US rating
    if let usRating = response.results.first(where: { $0.iso_3166_1 == "US" })?.rating,
      !usRating.isEmpty
    {
      return usRating
    }

    // Fallback to first available rating
    if let anyRating = response.results.first(where: { !$0.rating.isEmpty })?.rating {
      return anyRating
    }

    return "NR"
  }

  func fetchSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> [Title.Episode] {
    let urlString =
      "\(tmdbBaseURL ?? "")/3/tv/\(tvId)/season/\(seasonNumber)?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    let response = try await fetchAndDecode(url: url, type: SeasonDetailResponse.self)
    return response.episodes ?? []
  }

  func fetchPersonCredits(personId: Int) async throws -> [Title] {
    // Combined credits (Movie + TV)
    let urlString =
      "\(tmdbBaseURL ?? "")/3/person/\(personId)/combined_credits?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }

    struct PersonCombinedCredits: Decodable {
      let cast: [Title]
      let crew: [Title]
    }

    let response = try await fetchAndDecode(url: url, type: PersonCombinedCredits.self)

    // Merge unique titles by ID (using Dictionary to handle class instance uniqueness)
    var uniqueTitlesDict = [Int: Title]()

    // Add cast
    for title in response.cast {
      if let id = title.id {
        uniqueTitlesDict[id] = title
      }
    }

    // Add crew (Director/Creator/Executive)
    // Add crew (Director/Creator only) to avoid clutter from Producer roles
    for title in response.crew {
      if let id = title.id {
        // Filter out Producer roles which cause confusion (e.g. Margot Robbie in Saltburn)
        // Only include primary creative roles like Director or Creator (for TV)
        if let job = title.job, job == "Director" || job == "Creator" {
          // Only add if not already present from cast
          if uniqueTitlesDict[id] == nil {
            uniqueTitlesDict[id] = title
          }
        }
      }
    }

    let sorted = Array(uniqueTitlesDict.values).sorted {
      ($0.voteCount ?? 0) > ($1.voteCount ?? 0)  // Sort by popularity/vote count
    }

    return sorted
  }

  func fetchTrendingPeople() async throws -> [Person] {
    let urlString = "\(tmdbBaseURL ?? "")/3/person/popular?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: TrendingPersonResponse.self).results
  }

  func fetchSearchPeople(query: String) async throws -> [Person] {
    guard !query.isEmpty else { return [] }
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString =
      "\(tmdbBaseURL ?? "")/3/search/person?api_key=\(tmdbAPIKey ?? "")&query=\(encodedQuery)"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: TrendingPersonResponse.self).results
  }

  func fetchPersonDetails(personId: Int) async throws -> PersonDetail {
    let urlString = "\(tmdbBaseURL ?? "")/3/person/\(personId)?api_key=\(tmdbAPIKey ?? "")"
    guard let url = URL(string: urlString) else { throw NetworkError.urlBuildFailed }
    return try await fetchAndDecode(url: url, type: PersonDetail.self)
  }

  //https://www.googleapis.com/youtube/v3/search?q=Breaking%20Bad%20trailer&key=APIKEY
  func fetchVideoId(for title: String) async throws -> String {
    guard let baseSearchURL = youtubeSearchURL else {
      throw NetworkError.missingConfig
    }

    guard let searchAPIKey = youtubeAPIKey else {
      throw NetworkError.missingConfig
    }

    let trailerSearch =
      title + YoutubeURLStrings.space.rawValue + YoutubeURLStrings.trailer.rawValue

    guard
      let fetchVideoURL = URL(string: baseSearchURL)?.appending(queryItems: [
        URLQueryItem(name: YoutubeURLStrings.queryShorten.rawValue, value: trailerSearch),
        URLQueryItem(name: YoutubeURLStrings.key.rawValue, value: searchAPIKey),
      ])
    else {
      throw NetworkError.urlBuildFailed
    }

    print(fetchVideoURL)

    return try await fetchAndDecode(url: fetchVideoURL, type: YoutubeSearchResponse.self).items?
      .first?.id?.videoId ?? ""
  }

  func fetchAndDecode<T: Decodable>(url: URL, type: T.Type) async throws -> T {
    let (data, urlResponse) = try await URLSession.shared.data(from: url)

    guard let response = urlResponse as? HTTPURLResponse, response.statusCode == 200 else {
      throw NetworkError.badURLResponse(
        underlyingError: NSError(
          domain: "DataFetcher",
          code: (urlResponse as? HTTPURLResponse)?.statusCode ?? -1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP Response"]))
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(type, from: data)
  }

  func fetchTitles(
    for media: String, by type: String, with title: String? = nil, year: Int? = nil,
    genreId: Int? = nil, keywords: String? = nil, excludeGenres: String? = nil,
    originalLanguage: String? = nil, originCountry: String? = nil,
    voteAverageMin: Double? = nil, voteCountMin: Int? = nil, voteCountMax: Int? = nil,
    releaseDateGte: String? = nil, releaseDateLte: String? = nil, runtimeLte: Int? = nil,
    sortBy: String? = nil,
    page: Int = 1
  )
    async throws -> [Title]
  {
    let fetchTitlesURL = try buildURL(
      media: media, type: type, searchPhrase: title, year: year, genreId: genreId,
      keywords: keywords, excludeGenres: excludeGenres, originalLanguage: originalLanguage,
      originCountry: originCountry, voteAverageMin: voteAverageMin, voteCountMin: voteCountMin,
      voteCountMax: voteCountMax, releaseDateGte: releaseDateGte, releaseDateLte: releaseDateLte,
      runtimeLte: runtimeLte, sortBy: sortBy, page: page)

    guard let fetchTitlesURL = fetchTitlesURL else {
      throw NetworkError.urlBuildFailed
    }

    print(fetchTitlesURL)
    var titles = try await fetchAndDecode(url: fetchTitlesURL, type: TMDBAPIObject.self).results
    Constants.addPosterPath(to: &titles)
    return titles
  }

  func fetchTitlesDTO(
    for media: String, by type: String, with title: String? = nil, year: Int? = nil,
    genreId: Int? = nil, keywords: String? = nil, excludeGenres: String? = nil,
    originalLanguage: String? = nil, originCountry: String? = nil,
    voteAverageMin: Double? = nil, voteCountMin: Int? = nil, voteCountMax: Int? = nil,
    releaseDateGte: String? = nil, releaseDateLte: String? = nil, runtimeLte: Int? = nil,
    sortBy: String? = nil,
    page: Int = 1
  )
    async throws -> [TitleDTO]
  {
    let fetchTitlesURL = try buildURL(
      media: media, type: type, searchPhrase: title, year: year, genreId: genreId,
      keywords: keywords, excludeGenres: excludeGenres, originalLanguage: originalLanguage,
      originCountry: originCountry, voteAverageMin: voteAverageMin, voteCountMin: voteCountMin,
      voteCountMax: voteCountMax, releaseDateGte: releaseDateGte, releaseDateLte: releaseDateLte,
      runtimeLte: runtimeLte, sortBy: sortBy, page: page)

    guard let fetchTitlesURL = fetchTitlesURL else {
      throw NetworkError.urlBuildFailed
    }

    print(fetchTitlesURL)
    var titles = try await fetchAndDecode(url: fetchTitlesURL, type: TMDBAPIObjectDTO.self).results
    
    // Apply poster path fix manually for DTOs
    for index in titles.indices {
      if let path = titles[index].posterPath, !path.isEmpty, !path.contains("http") {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        titles[index].posterPath = Constants.posterURLStart + cleanPath
      }
    }
    
    return titles
  }

  private func buildURL(
    media: String, type: String, searchPhrase: String? = nil, year: Int? = nil, genreId: Int? = nil,
    keywords: String? = nil, excludeGenres: String? = nil, originalLanguage: String? = nil,
    originCountry: String? = nil, voteAverageMin: Double? = nil, voteCountMin: Int? = nil,
    voteCountMax: Int? = nil, releaseDateGte: String? = nil, releaseDateLte: String? = nil,
    runtimeLte: Int? = nil, sortBy: String? = nil, page: Int = 1
  )
    throws -> URL?
  {
    guard let baseURL = tmdbBaseURL else {
      throw NetworkError.missingConfig
    }
    guard let apiKey = tmdbAPIKey else {
      throw NetworkError.missingConfig
    }

    var path: String

    if type == "trending" {
      // "multi" is not a valid media type for trending; use "all" instead.
      let trendingMedia = (media == "multi" ? "all" : media)
      path = "3/\(type)/\(trendingMedia)/day"
    } else if type == "top_rated" || type == "upcoming" || type == "now_playing"
      || type == "popular" || type == "airing_today" || type == "on_the_air"
    {
      path = "3/\(media)/\(type)"
    } else if type == "search" {
      path = "3/\(type)/\(media)"
    } else if type == "discover" {
      path = "3/discover/\(media)"
    } else {
      throw NetworkError.urlBuildFailed
    }

    var urlQueryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "page", value: String(page)),
    ]

    if let searchPhrase {
      urlQueryItems.append(URLQueryItem(name: "query", value: searchPhrase))
    }

    if let year = year {
      if media == "movie" {
        urlQueryItems.append(URLQueryItem(name: "primary_release_year", value: String(year)))
      } else if media == "tv" {
        urlQueryItems.append(URLQueryItem(name: "first_air_date_year", value: String(year)))
      }
      // Sort by popularity to show best results first
      urlQueryItems.append(URLQueryItem(name: "sort_by", value: "popularity.desc"))
    }

    // Advanced Filters for Discover
    if type == "discover" {
      // Use provided sortBy or default to popularity.desc
      let sortOption = sortBy ?? "popularity.desc"
      urlQueryItems.append(URLQueryItem(name: "sort_by", value: sortOption))

      if let genreId = genreId {
        urlQueryItems.append(URLQueryItem(name: "with_genres", value: String(genreId)))
      }
      if let keywords = keywords {
        urlQueryItems.append(URLQueryItem(name: "with_keywords", value: keywords))
      }
      if let excludeGenres = excludeGenres {
        urlQueryItems.append(URLQueryItem(name: "without_genres", value: excludeGenres))
      }
      if let originalLanguage = originalLanguage {
        urlQueryItems.append(URLQueryItem(name: "with_original_language", value: originalLanguage))
      }
      if let voteAverageMin = voteAverageMin {
        urlQueryItems.append(URLQueryItem(name: "vote_average.gte", value: String(voteAverageMin)))
      }
      if let voteCountMin = voteCountMin {
        urlQueryItems.append(URLQueryItem(name: "vote_count.gte", value: String(voteCountMin)))
      }
      if let voteCountMax = voteCountMax {
        urlQueryItems.append(URLQueryItem(name: "vote_count.lte", value: String(voteCountMax)))
      }
      if let originCountry = originCountry {
        urlQueryItems.append(URLQueryItem(name: "with_origin_country", value: originCountry))
      }
      if let releaseDateGte = releaseDateGte {
        if media == "movie" {
          urlQueryItems.append(
            URLQueryItem(name: "primary_release_date.gte", value: releaseDateGte))
        } else {
          urlQueryItems.append(URLQueryItem(name: "first_air_date.gte", value: releaseDateGte))
        }
      }
      if let releaseDateLte = releaseDateLte {
        if media == "movie" {
          urlQueryItems.append(
            URLQueryItem(name: "primary_release_date.lte", value: releaseDateLte))
        } else {
          urlQueryItems.append(URLQueryItem(name: "first_air_date.lte", value: releaseDateLte))
        }
      }
      if let runtimeLte = runtimeLte {
        urlQueryItems.append(URLQueryItem(name: "with_runtime.lte", value: String(runtimeLte)))
      }
    } else {
      // Support genreId for non-discover calls if needed (rare, but keeping existing logic just in case)
      if let genreId = genreId {
        urlQueryItems.append(URLQueryItem(name: "with_genres", value: String(genreId)))
      }
    }

    guard
      let url = URL(string: baseURL)?
        .appending(path: path)
        .appending(queryItems: urlQueryItems)
    else {
      throw NetworkError.urlBuildFailed
    }

    return url
  }
}
