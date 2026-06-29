import Foundation

@Observable
@MainActor
class ViewModel {
  private let dataFetcher = DataFetcher()

  enum FetchStatus: Equatable {
    case notStarted
    case fetching
    case success
    case failed(underlyingError: Error)

    static func == (lhs: FetchStatus, rhs: FetchStatus) -> Bool {
      switch (lhs, rhs) {
      case (.notStarted, .notStarted): return true
      case (.fetching, .fetching): return true
      case (.success, .success): return true
      case (.failed, .failed): return true  // Consider errors equal for status check purposes
      default: return false
      }
    }
  }
  private(set) var homeStatus: FetchStatus = .notStarted
  private(set) var videoIdStatus: FetchStatus = .notStarted
  private(set) var upcomingStatus: FetchStatus = .notStarted

  var trendingMovies: [Title] = []
  var trendingTV: [Title] = []
  var topRatedMovies: [Title] = []
  var topRatedTV: [Title] = []
  var upcomingMovies: [Title] = []
  var inTheatresMovies: [Title] = []
  var popularMovies: [Title] = []
  var airingTodayTV: [Title] = []
  var onTheAirTV: [Title] = []
  var popularTV: [Title] = []
  var trendingPeople: [Person] = []

  var movieSections: [CategorySection] = []
  var tvSections: [CategorySection] = []
  var personalizedSections: [CategorySection] = []
  var countryMovieSections: [CategorySection] = []
  var countryTVSections: [CategorySection] = []
  private var hasFetchedCustomCategories = false
  private var isFetchingCustomCategories = false
  private var hasFetchedCountrySections = false
  private var isFetchingCountrySections = false
  private var personalizedRecommendationFingerprint: String?

  nonisolated static var deviceCountryCode: String {
    let code = Locale.autoupdatingCurrent.region?.identifier ?? "US"
    return code.isEmpty ? "US" : code.uppercased()
  }

  nonisolated static var deviceCountryName: String {
    Locale.autoupdatingCurrent.localizedString(forRegionCode: deviceCountryCode) ?? deviceCountryCode
  }

  struct CategorySection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [Title]
  }

  struct CategorySectionDTO: Sendable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [TitleDTO]
  }

  var featuredTitles: [Title] {
    // Interleave movies and TV for variety
    var combined: [Title] = []
    let maxCount = max(trendingMovies.count, trendingTV.count)
    for i in 0..<maxCount {
      if i < trendingMovies.count { combined.append(trendingMovies[i]) }
      if i < trendingTV.count { combined.append(trendingTV[i]) }
    }
    // Limit to top 20 for carousel
    return Array(combined.prefix(20))
  }

  var countryFeaturedTitles: [Title] {
    var combined: [Title] = []
    let movieItems = countryMovieSections.flatMap(\.items)
    let tvItems = countryTVSections.flatMap(\.items)
    let maxCount = max(movieItems.count, tvItems.count)

    for index in 0..<maxCount {
      if index < movieItems.count { combined.append(movieItems[index]) }
      if index < tvItems.count { combined.append(tvItems[index]) }
    }

    var seen = Set<String>()
    return Array(combined.filter { title in
      seen.insert(title.stableDisplayID).inserted
    }.prefix(20))
  }

  var heroTitle = Title.previewTitles[0]
  var videoId = ""
  // Pagination State
  private var currentGenrePage = 1
  private var currentGenreId: Int? = nil
  private var currentGenreType: String? = nil
  private var currentSortOption: SortOption? = .defaults
  private var isFetchingMore = false

  private func failure<T>(from result: Result<T, Error>) -> Error? {
    if case .failure(let error) = result {
      return error
    }
    return nil
  }

  func getTitles() async {
    homeStatus = .fetching

    // Use a TaskGroup or just separate standard Tasks if we want parallelism without fail-fast.
    // simpler approach: async let with individual try? or Result type.
    // OR: Just wrap each critical section in its own do-catch inside the async function.

    if trendingMovies.isEmpty {
      // We will try to fetch as much as possible.
      // Critical: Trending Movies/TV (for Hero + Lists)
      // Non-critical: Trending People, etc.

      // Execute fetches in parallel
      async let tMoviesResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "movie", by: "trending"))
        } catch { return .failure(error) }
      }()

      async let tTVResult: Result<[TitleDTO], Error> = {
        do { return .success(try await dataFetcher.fetchTitlesDTO(for: "tv", by: "trending")) } catch {
          return .failure(error)
        }
      }()

      async let tRMoviesResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "movie", by: "top_rated"))
        } catch { return .failure(error) }
      }()

      async let tRTVResult: Result<[TitleDTO], Error> = {
        do { return .success(try await dataFetcher.fetchTitlesDTO(for: "tv", by: "top_rated")) } catch
        { return .failure(error) }
      }()

      async let inTheatresResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "movie", by: "now_playing"))
        } catch { return .failure(error) }
      }()

      async let upcomingResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "movie", by: "upcoming"))
        } catch { return .failure(error) }
      }()

      async let popularResult: Result<[TitleDTO], Error> = {
        do { return .success(try await dataFetcher.fetchTitlesDTO(for: "movie", by: "popular")) } catch
        { return .failure(error) }
      }()

      async let peopleResult: Result<[Person], Error> = {
        do { return .success(try await dataFetcher.fetchTrendingPeople()) } catch {
          return .failure(error)
        }
      }()

      // New TV Fetches
      async let airingTodayResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "tv", by: "airing_today"))
        } catch { return .failure(error) }
      }()

      async let onTheAirResult: Result<[TitleDTO], Error> = {
        do {
          return .success(try await dataFetcher.fetchTitlesDTO(for: "tv", by: "on_the_air"))
        } catch { return .failure(error) }
      }()

      async let popularTVResult: Result<[TitleDTO], Error> = {
        do { return .success(try await dataFetcher.fetchTitlesDTO(for: "tv", by: "popular")) } catch {
          return .failure(error)
        }
      }()

      // Await all results
      let tMovies = await tMoviesResult
      let tTV = await tTVResult
      let tRMovies = await tRMoviesResult
      let tRTV = await tRTVResult
      let inTheatres = await inTheatresResult
      let upcoming = await upcomingResult
      let popular = await popularResult
      let people = await peopleResult
      let airingToday = await airingTodayResult
      let onTheAir = await onTheAirResult
      let popTV = await popularTVResult

      // Process Results
      // We consider it a "success" if we get at least SOME content.

      switch tMovies {
      case .success(let dtos): self.trendingMovies = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed to fetch trending movies: \(error)")
      }

      switch tTV {
      case .success(let dtos): self.trendingTV = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed to fetch trending TV: \(error)")
      }

      switch tRMovies {
      case .success(let dtos): self.topRatedMovies = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed top rated movies: \(error)")
      }

      switch tRTV {
      case .success(let dtos): self.topRatedTV = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed top rated TV: \(error)")
      }

      switch inTheatres {
      case .success(let dtos): self.inTheatresMovies = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed in theatres: \(error)")
      }

      switch upcoming {
      case .success(let dtos):
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let filtered = self.filterTitles(dtos.map { Title(dto: $0) })
        self.upcomingMovies = filtered.filter { ($0.releaseDate ?? "") > today }
      case .failure(let error): print("Failed upcoming: \(error)")
      }

      switch popular {
      case .success(let dtos): self.popularMovies = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed popular: \(error)")
      }

      switch people {
      case .success(let p):
        self.trendingPeople = p.filter { $0.profilePath != nil && !$0.name.isEmpty }
      case .failure(let error):
        print("Failed trending people: \(error)")
      }

      switch airingToday {
      case .success(let dtos): self.airingTodayTV = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed airing today: \(error)")
      }

      switch onTheAir {
      case .success(let dtos): self.onTheAirTV = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed on the air: \(error)")
      }

      switch popTV {
      case .success(let dtos): self.popularTV = self.filterTitles(dtos.map { Title(dto: $0) })
      case .failure(let error): print("Failed popular TV: \(error)")
      }

      // Hero Image Logic
      if let title = trendingMovies.randomElement() {
        heroTitle = title
      }

      let hasFetchedContent =
        !trendingMovies.isEmpty || !trendingTV.isEmpty || !inTheatresMovies.isEmpty ||
        !popularMovies.isEmpty || !popularTV.isEmpty || !topRatedMovies.isEmpty ||
        !topRatedTV.isEmpty || !upcomingMovies.isEmpty || !airingTodayTV.isEmpty ||
        !onTheAirTV.isEmpty || !trendingPeople.isEmpty

      var firstError: Error?
      firstError = firstError ?? failure(from: tMovies)
      firstError = firstError ?? failure(from: tTV)
      firstError = firstError ?? failure(from: tRMovies)
      firstError = firstError ?? failure(from: tRTV)
      firstError = firstError ?? failure(from: inTheatres)
      firstError = firstError ?? failure(from: upcoming)
      firstError = firstError ?? failure(from: popular)
      firstError = firstError ?? failure(from: people)
      firstError = firstError ?? failure(from: airingToday)
      firstError = firstError ?? failure(from: onTheAir)
      firstError = firstError ?? failure(from: popTV)

      if hasFetchedContent {
        homeStatus = .success
      } else if let firstError {
        homeStatus = .failed(underlyingError: firstError)
      } else {
        homeStatus = .success
      }

    } else {
      homeStatus = .success
    }
  }

  func getVideoId(for title: String) async {
    videoIdStatus = .fetching

    do {
      videoId = try await dataFetcher.fetchVideoId(for: title)
      videoIdStatus = .success
    } catch {
      print(error)
      videoIdStatus = .failed(underlyingError: error)
    }
  }

  func loadPersonalizedDiscoveryIfNeeded(from libraryItems: [UserLibraryItem]) async {
    await refreshPersonalizedDiscovery(from: libraryItems)
  }

  func refreshPersonalizedDiscovery(from libraryItems: [UserLibraryItem]) async {
    let engine = RecommendationEngine(dataFetcher: dataFetcher)
    let fingerprint = engine.fingerprint(for: libraryItems)
    guard personalizedRecommendationFingerprint != fingerprint else { return }

    let sections = await engine.buildSections(from: libraryItems)
    personalizedRecommendationFingerprint = fingerprint
    personalizedSections = sections.map { section in
      CategorySection(
        title: section.title,
        subtitle: section.subtitle,
        items: filterTitles(section.items)
      )
    }
  }

  func getUpcomingMovies() async {
    upcomingStatus = .fetching

    do {
      let titles = try await dataFetcher.fetchTitles(for: "movie", by: "upcoming")
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      let today = formatter.string(from: Date())
      let filtered = self.filterTitles(titles)
      upcomingMovies = filtered.filter { ($0.releaseDate ?? "") > today }
      upcomingStatus = .success
    } catch {
      print(error)
      upcomingStatus = .failed(underlyingError: error)
    }
  }

  func getGenreContent(for genreId: Int, type: String? = nil, sortOption: SortOption = .defaults) async {
    homeStatus = .fetching

    // Reset Pagination
    currentGenrePage = 1
    currentGenreId = genreId
    currentGenreType = type
    currentSortOption = sortOption
    
    // Sort Logic


    var fetchedMovies: [Title] = []
    var fetchedTV: [Title] = []

    // 1. Movies (In Theatres, Popular, Upcoming)
    async let moviesResult: Result<[TitleDTO], Error> = {
      if type == nil || type == "movie" {
        do {
          let params = self.sortParams(for: "movie", option: sortOption)
          return .success(
            try await dataFetcher.fetchTitlesDTO(for: "movie", by: "discover", genreId: genreId, voteCountMin: params.voteCountMin, sortBy: params.sortBy))
        } catch { return .failure(error) }
      } else {
        return .success([])
      }
    }()

    // 2. TV Shows (Trending/Popular)
    async let tvResult: Result<[TitleDTO], Error> = {
      if type == nil || type == "tv" {
        do {
          let params = self.sortParams(for: "tv", option: sortOption)
          return .success(
            try await dataFetcher.fetchTitlesDTO(for: "tv", by: "discover", genreId: genreId, voteCountMin: params.voteCountMin, sortBy: params.sortBy))
        } catch { return .failure(error) }
      } else {
        return .success([])
      }
    }()

    let mRes = await moviesResult
    let tRes = await tvResult

    switch mRes {
    case .success(let dtos): fetchedMovies = self.filterTitles(dtos.map { Title(dto: $0) })
    case .failure(let error): print("Failed to fetch genre movies: \(error)")
    }

    switch tRes {
    case .success(let dtos): fetchedTV = self.filterTitles(dtos.map { Title(dto: $0) })
    case .failure(let error): print("Failed to fetch genre TV: \(error)")
    }

    // Populate ViewModel properties to reflect the filtered state
    // We clear the lists if they weren't fetched to avoid showing stale data from a previous state

    if type == "movie" {
      // Movies only selected
      inTheatresMovies = fetchedMovies
      popularMovies = []  // Clear to remove stale data
      upcomingMovies = []  // Clear to remove stale data
      topRatedMovies = []  // Clear to remove stale data
      trendingMovies = []  // Clear stale

      // Clear TV
      trendingTV = []
      popularTV = []
      topRatedTV = []
      airingTodayTV = []
      onTheAirTV = []
    } else if type == "tv" {
      // TV only selected
      // Clear Movies
      inTheatresMovies = []
      popularMovies = []
      upcomingMovies = []
      topRatedMovies = []
      trendingMovies = []

      // Update TV
      trendingTV = fetchedTV
      popularTV = []  // Clear stale
      topRatedTV = []  // Clear stale
      airingTodayTV = []  // Clear stale
      onTheAirTV = []  // Clear stale
    } else {
      // Both (type is nil - fetch both movies and TV)
      inTheatresMovies = fetchedMovies
      popularMovies = []
      upcomingMovies = []
      topRatedMovies = []
      trendingMovies = []

      trendingTV = fetchedTV
      popularTV = []
      topRatedTV = []
      airingTodayTV = []
      onTheAirTV = []
    }

    homeStatus = .success
  }

  func loadMoreGenreContent() async {
    guard let genreId = currentGenreId, homeStatus != .fetching, !isFetchingMore else { return }

    isFetchingMore = true
    defer { isFetchingMore = false }

    currentGenrePage += 1
    let page = currentGenrePage
    let type = currentGenreType
    let sortOption = currentSortOption ?? .defaults
    
    // Sort Logic (Duplicated locally for now, could be helper)


    // Fetch Next Page
    async let moviesResult: Result<[TitleDTO], Error> = {
      if type == nil || type == "movie" {
        do {
          return .success(
            try await dataFetcher.fetchTitlesDTO(
              for: "movie", by: "discover", genreId: genreId, voteCountMin: self.sortParams(for: "movie", option: sortOption).voteCountMin, sortBy: self.sortParams(for: "movie", option: sortOption).sortBy, page: page))
        } catch { return .failure(error) }
      } else {
        return .success([])
      }
    }()

    async let tvResult: Result<[TitleDTO], Error> = {
      if type == nil || type == "tv" {
        do {
          return .success(
            try await dataFetcher.fetchTitlesDTO(
              for: "tv", by: "discover", genreId: genreId, voteCountMin: self.sortParams(for: "tv", option: sortOption).voteCountMin, sortBy: self.sortParams(for: "tv", option: sortOption).sortBy, page: page))
        } catch { return .failure(error) }
      } else {
        return .success([])
      }
    }()

    let mRes = await moviesResult
    let tRes = await tvResult

    // Append Results safely (filtering duplicates against existing data)
    switch mRes {
    case .success(let dtos):
      let newTitles = dtos.map { Title(dto: $0) }
      let filtered = self.filterTitles(newTitles)
      // Deduplicate before append
      let existingIds = Set(inTheatresMovies.compactMap { $0.id })
      let uniqueNew = filtered.filter { title in
          guard let id = title.id else { return true }
          return !existingIds.contains(id)
      }
      
      if type == "movie" {
        inTheatresMovies.append(contentsOf: uniqueNew)
      } else if type == nil {
        inTheatresMovies.append(contentsOf: uniqueNew)
      }
    case .failure(let error): print("Failed load more genre movies: \(error)")
    }

    switch tRes {
    case .success(let dtos):
      let newTitles = dtos.map { Title(dto: $0) }
      let filtered = self.filterTitles(newTitles)
       // Deduplicate before append
      let existingIds = Set(trendingTV.compactMap { $0.id })
      let uniqueNew = filtered.filter { title in
          guard let id = title.id else { return true }
          return !existingIds.contains(id)
      }
      
      if type == "tv" {
        trendingTV.append(contentsOf: uniqueNew)
      } else if type == nil {
        trendingTV.append(contentsOf: uniqueNew)
      }
    case .failure(let error): print("Failed load more genre TV: \(error)")
    }
  }

  func loadCustomCategoriesIfNeeded() async {
    guard !hasFetchedCustomCategories, !isFetchingCustomCategories else { return }
    isFetchingCustomCategories = true
    defer { isFetchingCustomCategories = false }
    await fetchCustomCategories()
    hasFetchedCustomCategories = true
  }

  func loadCountrySectionsIfNeeded() async {
    guard !hasFetchedCountrySections, !isFetchingCountrySections else { return }
    isFetchingCountrySections = true
    defer { isFetchingCountrySections = false }

    await fetchCountrySections()
    hasFetchedCountrySections = true
  }

  private func fetchCountrySections() async {
    let countryCode = Self.deviceCountryCode
    let countryName = Self.deviceCountryName

    async let popularMoviesResult: Result<[TitleDTO], Error> = {
      do {
        return .success(
          try await dataFetcher.fetchTitlesDTO(
            for: "movie",
            by: "discover",
            originCountry: countryCode,
            voteCountMin: 20,
            sortBy: "popularity.desc"
          )
        )
      } catch {
        return .failure(error)
      }
    }()

    async let topRatedMoviesResult: Result<[TitleDTO], Error> = {
      do {
        return .success(
          try await dataFetcher.fetchTitlesDTO(
            for: "movie",
            by: "discover",
            originCountry: countryCode,
            voteAverageMin: 7.0,
            voteCountMin: 50,
            sortBy: "vote_average.desc"
          )
        )
      } catch {
        return .failure(error)
      }
    }()

    async let popularTVResult: Result<[TitleDTO], Error> = {
      do {
        return .success(
          try await dataFetcher.fetchTitlesDTO(
            for: "tv",
            by: "discover",
            originCountry: countryCode,
            voteCountMin: 10,
            sortBy: "popularity.desc"
          )
        )
      } catch {
        return .failure(error)
      }
    }()

    let popularMovies = await popularMoviesResult
    let topRatedMovies = await topRatedMoviesResult
    let popularTV = await popularTVResult

    var movieSections: [CategorySection] = []
    var tvSections: [CategorySection] = []

    switch popularMovies {
    case .success(let dtos):
      let items = localSectionTitles(from: dtos)
      if !items.isEmpty {
        movieSections.append(
          CategorySection(
            title: "Popular in \(countryName)",
            subtitle: "Movies produced in \(countryName)",
            items: items
          )
        )
      }
    case .failure(let error):
      print("Failed country movies for \(countryCode): \(error)")
    }

    switch topRatedMovies {
    case .success(let dtos):
      let items = localSectionTitles(from: dtos)
      if items.count >= 8 {
        movieSections.append(
          CategorySection(
            title: "Top Rated from \(countryName)",
            subtitle: "Acclaimed local movies",
            items: items
          )
        )
      }
    case .failure(let error):
      print("Failed top rated country movies for \(countryCode): \(error)")
    }

    switch popularTV {
    case .success(let dtos):
      let items = localSectionTitles(from: dtos)
      if !items.isEmpty {
        tvSections.append(
          CategorySection(
            title: "\(countryName) Shows",
            subtitle: "Series produced in \(countryName)",
            items: items
          )
        )
      }
    case .failure(let error):
      print("Failed country TV for \(countryCode): \(error)")
    }

    self.countryMovieSections = movieSections
    self.countryTVSections = tvSections
  }

  private func localSectionTitles(from dtos: [TitleDTO]) -> [Title] {
    var seen = Set<String>()
    return dtos.map { Title(dto: $0) }.filter { title in
      guard let posterPath = title.posterPath, !posterPath.isEmpty else { return false }
      guard (title.voteAverage ?? 0) < 10 else { return false }
      return seen.insert(title.stableDisplayID).inserted
    }
  }

  private func fetchCustomCategories() async {
    // Define category configurations with new parameters
    struct CategoryConfig {
      let title: String
      let subtitle: String
      let keywords: String?
      let genres: String?
      let excludeGenres: String?
      let language: String?
      let originCountry: String?
      let voteAvg: Double?
      let voteCount: Int?
      let voteCountMax: Int?
      let releaseDateGte: String?
      let releaseDateLte: String?
      let runtimeLte: Int?
      let maxSeasons: Int?
      let isMovieOnly: Bool
      let isTVOnly: Bool
    }

    // Movie-specific sections
    let movieConfigs: [CategoryConfig] = [
      CategoryConfig(
        title: "Festival Favorites", subtitle: "Hidden gems from film festivals",
        keywords: "207474", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Cult Classics", subtitle: "Fan-favorite oddballs",
        keywords: "15060", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Feel-Good Movies", subtitle: "Heartwarming comfort watches",
        keywords: "9799", genres: "35,10749", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 100, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Slow Burn Thrillers", subtitle: "Tension that builds gradually",
        keywords: "207265", genres: "53", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Short & Sweet", subtitle: "Under 100 minutes",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 500, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: 100, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Critics' Darlings", subtitle: "High rating, lower popularity",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 7.5, voteCount: 50, voteCountMax: 500, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "90s Nostalgia", subtitle: "Released between 1990–1999",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 500, voteCountMax: nil, releaseDateGte: "1990-01-01",
        releaseDateLte: "1999-12-31",
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "2000s Throwback", subtitle: "Released between 2000–2009",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 500, voteCountMax: nil, releaseDateGte: "2000-01-01",
        releaseDateLte: "2009-12-31",
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Family Time", subtitle: "Family-friendly picks",
        keywords: nil, genres: "10751", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.0, voteCount: 100, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Mind-Bending", subtitle: "Twisty, high-concept stories",
        keywords: "310", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "Underrated Gems", subtitle: "Decent rating with low vote count",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 50, voteCountMax: 1000, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
      CategoryConfig(
        title: "International Hits", subtitle: "High-rated non-English titles",
        keywords: nil, genres: nil, excludeGenres: nil, language: "fr|de|es|it|pt|ja|ko|zh|hi",
        originCountry: nil,
        voteAvg: 7.0, voteCount: 500, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: true, isTVOnly: false),
    ]

    // TV-specific sections
    let tvConfigs: [CategoryConfig] = [
      CategoryConfig(
        title: "Comfort Binge", subtitle: "Easy-to-watch episodic shows",
        keywords: "288414", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Mini-Series Spotlight", subtitle: "Limited series only",
        keywords: "10714", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: 1, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Underrated Series", subtitle: "High rating, low popularity",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 7.5, voteCount: 50, voteCountMax: 500, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Slow Burn Series", subtitle: "Long-form, serialized storytelling",
        keywords: "207265", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Feel-Good TV", subtitle: "Lighthearted, uplifting shows",
        keywords: "9799", genres: "35", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.5, voteCount: 100, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Crime & Mystery", subtitle: "Detective and investigation series",
        keywords: nil, genres: "80,9648", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: 100, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "K-Drama Corner", subtitle: "Korean dramas",
        keywords: nil, genres: nil, excludeGenres: nil, language: "ko", originCountry: "KR",
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Sitcom Classics", subtitle: "Comedy shows with many seasons",
        keywords: nil, genres: "35", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 7.0, voteCount: 500, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Docu-Series", subtitle: "Non-fiction and true-story series",
        keywords: nil, genres: "99", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: 50, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Family Watchlist", subtitle: "Family-appropriate series",
        keywords: nil, genres: "10751", excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 6.0, voteCount: 100, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
      CategoryConfig(
        title: "Hidden Gems", subtitle: "Vote count floor + mid popularity",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 7.0, voteCount: 100, voteCountMax: 1000, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: true),
    ]

    // Shared sections (appear in both Movies and Shows)
    let sharedConfigs: [CategoryConfig] = [
      CategoryConfig(
        title: "Asian Cinema", subtitle: "Best from the East",
        keywords: nil, genres: nil, excludeGenres: nil, language: "ja|ko|zh|hi|th",
        originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Anime", subtitle: "Japanese Animation",
        keywords: nil, genres: "16", excludeGenres: nil, language: "ja", originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Superhero", subtitle: "Heroes and Villains",
        keywords: "9715", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Adult Animation", subtitle: "Not for kids",
        keywords: nil, genres: "16", excludeGenres: "10751", language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Award Winning", subtitle: "Critically Acclaimed",
        keywords: nil, genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: 8.0, voteCount: 1000, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Real Life", subtitle: "Based on true stories",
        keywords: "9672", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Blockbuster", subtitle: "Big budget hits",
        keywords: "187056", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
      CategoryConfig(
        title: "Biographical", subtitle: "Life stories",
        keywords: "6092", genres: nil, excludeGenres: nil, language: nil, originCountry: nil,
        voteAvg: nil, voteCount: nil, voteCountMax: nil, releaseDateGte: nil, releaseDateLte: nil,
        runtimeLte: nil, maxSeasons: nil, isMovieOnly: false, isTVOnly: false),
    ]

    // Helper function to fetch a category
    func fetchCategory(_ config: CategoryConfig, for media: String) async -> CategorySectionDTO? {
      do {
        let genreId: Int? = config.genres?.split(separator: ",").first.flatMap { Int($0) }
        let titles = try await self.dataFetcher.fetchTitlesDTO(
          for: media, by: "discover",
          genreId: genreId,
          keywords: config.keywords,
          excludeGenres: config.excludeGenres,
          originalLanguage: config.language,
          originCountry: config.originCountry,
          voteAverageMin: config.voteAvg,
          voteCountMin: config.voteCount,
          voteCountMax: config.voteCountMax,
          releaseDateGte: config.releaseDateGte,
          releaseDateLte: config.releaseDateLte,
          runtimeLte: config.runtimeLte
        )
        var filteredTitles = titles
          
        // Post-fetch filtering for season count
        if let maxSeasons = config.maxSeasons {
            var validTitles: [TitleDTO] = []
            var knownTitles: [TitleDTO] = []
            var titlesToVerify: [TitleDTO] = []
            
            // 1. Separate known vs unknown
            for title in titles {
                if let seasons = title.numberOfSeasons {
                    if seasons <= maxSeasons {
                        knownTitles.append(title)
                    }
                } else {
                    titlesToVerify.append(title)
                }
            }
            
            validTitles.append(contentsOf: knownTitles)
            
            // 2. Fetch details for unknown titles
            // We use a task group to fetch details concurrently. 
            // We only return the NEW details object if valid.
            if !titlesToVerify.isEmpty {
                let verifiedTitles = await withTaskGroup(of: TitleDTO?.self) { group in
                    for title in titlesToVerify {
                        // Extract ID on current actor to avoid capturing object in closure
                        guard let id = title.id else { continue }
                        
                        group.addTask {
                            do {
                                let details = try await self.dataFetcher.fetchTitleDetailsDTO(for: media, id: id)
                                if let s = details.numberOfSeasons, s <= maxSeasons {
                                    return details
                                }
                            } catch {
                                print("Failed to verify title \(id) for category: \(error)")
                            }
                            return nil
                        }
                    }
                    
                    var results: [TitleDTO] = []
                    for await result in group {
                        if let valid = result {
                            results.append(valid)
                        }
                    }
                    return results
                }
                validTitles.append(contentsOf: verifiedTitles)
            }
            
            filteredTitles = validTitles
        }

        if !filteredTitles.isEmpty {
          // Filter out 10.0 ratings inline
          let finalTitles = filteredTitles.filter { ($0.voteAverage ?? 0) < 10.0 }
          if !finalTitles.isEmpty {
             return CategorySectionDTO(
               title: config.title, subtitle: config.subtitle, items: finalTitles)
          }
        }
      } catch {
        print("Failed to fetch \(media) category \(config.title): \(error)")
      }
      return nil
    }

    // Fetch for Movies (movie-only + shared configs)
    let allMovieConfigs = movieConfigs + sharedConfigs.filter { !$0.isTVOnly }
    await withTaskGroup(of: CategorySectionDTO?.self) { group in
      for config in allMovieConfigs {
        group.addTask {
          await fetchCategory(config, for: "movie")
        }
      }

      var sections: [CategorySection] = []
      for await sectionDTO in group {
        if let dto = sectionDTO {
          let items = dto.items.map { Title(dto: $0) }
          sections.append(CategorySection(title: dto.title, subtitle: dto.subtitle, items: items))
        }
      }
      // Sort to match config order
      self.movieSections = sections.sorted { s1, s2 in
        (allMovieConfigs.firstIndex(where: { $0.title == s1.title }) ?? 0)
          < (allMovieConfigs.firstIndex(where: { $0.title == s2.title }) ?? 0)
      }
    }

    // Fetch for TV (tv-only + shared configs)
    let allTVConfigs = tvConfigs + sharedConfigs.filter { !$0.isMovieOnly }
    await withTaskGroup(of: CategorySectionDTO?.self) { group in
      for config in allTVConfigs {
        group.addTask {
          await fetchCategory(config, for: "tv")
        }
      }

      var sections: [CategorySection] = []
      for await sectionDTO in group {
        if let dto = sectionDTO {
            let items = dto.items.map { Title(dto: $0) }
            sections.append(CategorySection(title: dto.title, subtitle: dto.subtitle, items: items))
        }
      }
      self.tvSections = sections.sorted { s1, s2 in
        (allTVConfigs.firstIndex(where: { $0.title == s1.title }) ?? 0)
          < (allTVConfigs.firstIndex(where: { $0.title == s2.title }) ?? 0)
      }
    }
  }

  // MARK: - Helper to filter out invalid/10.0 rated items
  private func filterTitles(_ titles: [Title]) -> [Title] {
    return titles.filter { ($0.voteAverage ?? 0) < 10.0 }
  }

  nonisolated private func sortParams(for mediaType: String, option: SortOption) -> (sortBy: String, voteCountMin: Int?) {
    switch option {
    case .defaults, .popularity:
        return ("popularity.desc", nil)
    case .name:
        return (mediaType == "movie" ? "original_title.asc" : "original_name.asc", nil)
    case .releaseDate:
        return (mediaType == "movie" ? "primary_release_date.desc" : "first_air_date.desc", nil)
    case .rating:
        return ("vote_average.desc", 200)
    }
  }
}
