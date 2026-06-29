import Foundation

struct RecommendationEngine {
  struct RecommendationSection {
    let title: String
    let subtitle: String
    let items: [Title]
  }

  struct TasteProfile {
    let fingerprint: String
    let excludedKeys: Set<String>
    let positiveSeeds: [TasteSeed]
    let negativeGenreWeights: [Int: Double]
    let preferredMediaWeights: [String: Double]
    let preferredDecades: [Int: Double]
    let preferredDirectors: Set<String>
  }

  struct TasteSeed {
    let item: UserLibraryItem
    let score: Double
    let genreIds: [Int]
    let releaseYear: Int?
    let directorNames: [String]

    var key: String { item.uniqueId }
  }

  struct MicrogenreRule {
    let title: String
    let subtitle: String
    let mediaType: String
    let genreIds: String?
    let keywords: String?
    let excludeGenres: String?
    let originalLanguage: String?
    let originCountry: String?
    let voteAverageMin: Double?
    let voteCountMin: Int?
    let voteCountMax: Int?
    let runtimeLte: Int?
    let evidenceGenreIds: Set<Int>
    let minimumEvidenceScore: Double
    let sortBy: String
  }

  struct Candidate {
    let title: Title
    let mediaType: String
    let sourceWeight: Double
    let matchedRule: MicrogenreRule?
  }

  private let dataFetcher: DataFetcher

  init(dataFetcher: DataFetcher) {
    self.dataFetcher = dataFetcher
  }

  func buildSections(from libraryItems: [UserLibraryItem]) async -> [RecommendationSection] {
    let profile = await buildTasteProfile(from: libraryItems)
    guard profile.positiveSeeds.count >= 4 else { return [] }

    let seedCandidates = await fetchSeedRecommendationCandidates(profile: profile)
    let microgenreSections = await fetchMicrogenreSections(profile: profile, seedCandidates: seedCandidates)

    var usedKeys = Set<String>()
    var sections: [RecommendationSection] = []

    for section in microgenreSections {
      let uniqueItems = section.items.filter { title in
        guard let key = recommendationKey(for: title, fallbackMediaType: nil) else { return false }
        guard !usedKeys.contains(key) else { return false }
        usedKeys.insert(key)
        return true
      }
      if uniqueItems.count >= 8 {
        sections.append(
          RecommendationSection(
            title: section.title,
            subtitle: section.subtitle,
            items: Array(uniqueItems.prefix(20))
          )
        )
      }
      if sections.count >= 5 { break }
    }

    return sections
  }

  func fingerprint(for libraryItems: [UserLibraryItem]) -> String {
    libraryItems
      .map { item in
        [
          item.uniqueId,
          String(format: "%.2f", item.userRating ?? -1),
          String(format: "%.2f", item.letterboxdRating ?? -1),
          item.isWatched ? "watched" : "unwatched",
          item.isWatchlist ? "watchlist" : "not-watchlist",
          item.isLetterboxdFavorite ? "favorite" : "not-favorite",
          String(Int(item.modifiedAt.timeIntervalSince1970))
        ].joined(separator: ":")
      }
      .sorted()
      .joined(separator: "|")
  }

  private func buildTasteProfile(from libraryItems: [UserLibraryItem]) async -> TasteProfile {
    let ratedItems = libraryItems
      .filter { item in
        item.isWatched || item.userRating != nil || item.letterboxdRating != nil || item.isLetterboxdFavorite
      }
      .sorted { tasteScore(for: $0) > tasteScore(for: $1) }

    var seeds: [TasteSeed] = []
    for item in Array(ratedItems.prefix(24)) {
      let score = tasteScore(for: item)
      let metadata = await metadata(for: item)
      seeds.append(
        TasteSeed(
          item: item,
          score: score,
          genreIds: metadata.genreIds,
          releaseYear: metadata.releaseYear,
          directorNames: item.directorNames
        )
      )
    }

    let positiveSeeds = seeds
      .filter { $0.score >= 7.0 || $0.item.isLetterboxdFavorite }
      .sorted { $0.score > $1.score }

    var negativeGenreWeights: [Int: Double] = [:]
    for seed in seeds where seed.score > 0 && seed.score <= 5.0 {
      for genreId in seed.genreIds {
        negativeGenreWeights[genreId, default: 0] += 6.0 - seed.score
      }
    }

    var preferredMediaWeights: [String: Double] = [:]
    var preferredDecades: [Int: Double] = [:]
    var preferredDirectors = Set<String>()
    for seed in positiveSeeds {
      preferredMediaWeights[seed.item.mediaType, default: 0] += seed.score
      if let releaseYear = seed.releaseYear {
        preferredDecades[(releaseYear / 10) * 10, default: 0] += seed.score
      }
      for director in seed.directorNames {
        preferredDirectors.insert(director.lowercased())
      }
    }

    return TasteProfile(
      fingerprint: fingerprint(for: libraryItems),
      excludedKeys: Set(libraryItems.map(\.uniqueId)),
      positiveSeeds: positiveSeeds,
      negativeGenreWeights: negativeGenreWeights,
      preferredMediaWeights: preferredMediaWeights,
      preferredDecades: preferredDecades,
      preferredDirectors: preferredDirectors
    )
  }

  private func metadata(for item: UserLibraryItem) async -> (genreIds: [Int], releaseYear: Int?) {
    if !item.genreIds.isEmpty || item.releaseYear != nil {
      return (item.genreIds, item.releaseYear)
    }

    do {
      let details = try await dataFetcher.fetchTitleDetailsDTO(for: item.mediaType, id: item.titleId)
      let yearText = (details.releaseDate ?? details.firstAirDate)?.prefix(4)
      return (
        details.genres?.map(\.id) ?? [],
        yearText.flatMap { Int($0) }
      )
    } catch {
      return ([], nil)
    }
  }

  private func fetchSeedRecommendationCandidates(profile: TasteProfile) async -> [Candidate] {
    await withTaskGroup(of: [Candidate].self) { group in
      for seed in profile.positiveSeeds.prefix(8) {
        group.addTask {
          do {
            let recommendations = try await dataFetcher.fetchRecommendations(
              for: seed.item.mediaType,
              id: seed.item.titleId
            )
            return recommendations.map { title in
              Candidate(
                title: title,
                mediaType: seed.item.mediaType,
                sourceWeight: 10 + seed.score,
                matchedRule: nil
              )
            }
          } catch {
            return []
          }
        }
      }

      var candidates: [Candidate] = []
      for await result in group {
        candidates.append(contentsOf: result)
      }
      return candidates
    }
  }

  private func fetchMicrogenreSections(
    profile: TasteProfile,
    seedCandidates: [Candidate]
  ) async -> [RecommendationSection] {
    await withTaskGroup(of: RecommendationSection?.self) { group in
      for rule in microgenreRules where evidenceScore(for: rule, profile: profile) >= rule.minimumEvidenceScore {
        group.addTask {
          await buildMicrogenreSection(rule: rule, profile: profile, seedCandidates: seedCandidates)
        }
      }

      var sections: [RecommendationSection] = []
      for await section in group {
        if let section {
          sections.append(section)
        }
      }
      return sections.sorted { sectionRank($0.title) < sectionRank($1.title) }
    }
  }

  private func buildMicrogenreSection(
    rule: MicrogenreRule,
    profile: TasteProfile,
    seedCandidates: [Candidate]
  ) async -> RecommendationSection? {
    var candidates = seedCandidates.filter { candidate in
      candidate.mediaType == rule.mediaType && title(candidate.title, matches: rule)
    }

    do {
      let discovered = try await dataFetcher.fetchTitlesDTO(
        for: rule.mediaType,
        by: "discover",
        genreIds: rule.genreIds,
        keywords: rule.keywords,
        excludeGenres: rule.excludeGenres,
        originalLanguage: rule.originalLanguage,
        originCountry: rule.originCountry,
        voteAverageMin: rule.voteAverageMin,
        voteCountMin: rule.voteCountMin,
        voteCountMax: rule.voteCountMax,
        runtimeLte: rule.runtimeLte,
        sortBy: rule.sortBy
      )
      candidates.append(
        contentsOf: discovered.map { dto in
          Candidate(
            title: Title(dto: dto),
            mediaType: rule.mediaType,
            sourceWeight: 4,
            matchedRule: rule
          )
        }
      )
    } catch {
      print("Failed microgenre section \(rule.title): \(error)")
    }

    let ranked = rankedTitles(from: candidates, rule: rule, profile: profile)
    guard ranked.count >= 8 else { return nil }
    return RecommendationSection(title: rule.title, subtitle: rule.subtitle, items: ranked)
  }

  private func rankedTitles(
    from candidates: [Candidate],
    rule: MicrogenreRule,
    profile: TasteProfile
  ) -> [Title] {
    var bestByKey: [String: (title: Title, score: Double)] = [:]

    for candidate in candidates {
      guard let key = recommendationKey(for: candidate.title, fallbackMediaType: candidate.mediaType) else {
        continue
      }
      guard !profile.excludedKeys.contains(key), hasPoster(candidate.title) else { continue }

      let score = score(candidate: candidate, rule: rule, profile: profile)
      if let existing = bestByKey[key], existing.score >= score {
        continue
      }
      var title = candidate.title
      title.mediaType = title.mediaType ?? candidate.mediaType
      bestByKey[key] = (title, score)
    }

    return bestByKey.values
      .sorted {
        if abs($0.score - $1.score) > 0.001 { return $0.score > $1.score }
        return ($0.title.voteCount ?? 0) > ($1.title.voteCount ?? 0)
      }
      .map(\.title)
  }

  private func score(candidate: Candidate, rule: MicrogenreRule, profile: TasteProfile) -> Double {
    let title = candidate.title
    let genreIds = title.genres?.map(\.id) ?? parseGenreIds(rule.genreIds)
    var score = candidate.sourceWeight

    score += Double(genreIds.filter { rule.evidenceGenreIds.contains($0) }.count) * 4
    score += (title.voteAverage ?? 0) * 1.4
    score += min(Double(title.voteCount ?? 0), 2_500) / 500

    if let mediaWeight = profile.preferredMediaWeights[candidate.mediaType] {
      score += min(mediaWeight / 10, 5)
    }

    if let year = releaseYear(for: title) {
      let decade = (year / 10) * 10
      score += min((profile.preferredDecades[decade] ?? 0) / 12, 3)
    }

    for genreId in genreIds {
      score -= profile.negativeGenreWeights[genreId, default: 0] * 1.5
    }

    if (title.voteCount ?? 0) < 25 && rule.voteCountMax == nil {
      score -= 5
    }

    return score
  }

  private func evidenceScore(for rule: MicrogenreRule, profile: TasteProfile) -> Double {
    profile.positiveSeeds.reduce(0) { score, seed in
      let overlap = seed.genreIds.filter { rule.evidenceGenreIds.contains($0) }.count
      guard overlap > 0 || rule.originalLanguage == "ko" && seed.item.mediaType == "tv" else {
        return score
      }
      return score + seed.score + Double(overlap * 2)
    }
  }

  private func title(_ title: Title, matches rule: MicrogenreRule) -> Bool {
    let ruleGenres = Set(parseGenreIds(rule.genreIds))
    if ruleGenres.isEmpty { return true }
    let titleGenres = Set(title.genres?.map(\.id) ?? [])
    return !titleGenres.isDisjoint(with: ruleGenres) || titleGenres.isEmpty
  }

  private func parseGenreIds(_ genreIds: String?) -> [Int] {
    (genreIds ?? "")
      .split(separator: ",")
      .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
  }

  private func recommendationKey(for title: Title, fallbackMediaType: String?) -> String? {
    guard let id = title.id else { return nil }
    let mediaType = title.mediaType ?? fallbackMediaType ?? (title.name == nil ? "movie" : "tv")
    return "\(mediaType)_\(id)"
  }

  private func hasPoster(_ title: Title) -> Bool {
    guard let posterPath = title.posterPath else { return false }
    return !posterPath.isEmpty
  }

  private func releaseYear(for title: Title) -> Int? {
    guard let text = title.releaseDate?.prefix(4) else { return nil }
    return Int(text)
  }

  private func tasteScore(for item: UserLibraryItem) -> Double {
    var score = item.userRating ?? item.letterboxdRating ?? (item.isWatched ? 6 : 0)
    if item.isLetterboxdFavorite {
      score = max(score, 9.5)
    }
    return score
  }

  private func sectionRank(_ title: String) -> Int {
    microgenreRules.firstIndex { $0.title == title } ?? Int.max
  }

  private var microgenreRules: [MicrogenreRule] {
    [
      MicrogenreRule(
        title: "Mind-Bending Mysteries",
        subtitle: "Twisty, high-concept stories matched to your taste",
        mediaType: "movie",
        genreIds: "9648,878,53",
        keywords: "310",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.4,
        voteCountMin: 80,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [9648, 878, 53],
        minimumEvidenceScore: 16,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Slow Burn Thrillers",
        subtitle: "Tension that takes its time",
        mediaType: "movie",
        genreIds: "53,18",
        keywords: "207265",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.3,
        voteCountMin: 80,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [53, 18, 9648],
        minimumEvidenceScore: 18,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Dark Crime & Mystery",
        subtitle: "Investigations, conspiracies, and shadowy turns",
        mediaType: "tv",
        genreIds: "80,9648",
        keywords: nil,
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.8,
        voteCountMin: 70,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [80, 9648, 53],
        minimumEvidenceScore: 16,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Feel-Good Comfort Watches",
        subtitle: "Warm, funny picks without heavy homework",
        mediaType: "movie",
        genreIds: "35,10749",
        keywords: "9799",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.4,
        voteCountMin: 80,
        voteCountMax: nil,
        runtimeLte: 115,
        evidenceGenreIds: [35, 10749, 10751],
        minimumEvidenceScore: 16,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Festival Favorites",
        subtitle: "Acclaimed discoveries with a curated edge",
        mediaType: "movie",
        genreIds: "18",
        keywords: "207474",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.6,
        voteCountMin: 40,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [18],
        minimumEvidenceScore: 20,
        sortBy: "vote_average.desc"
      ),
      MicrogenreRule(
        title: "Cult Classics",
        subtitle: "Offbeat fan favorites tuned to your library",
        mediaType: "movie",
        genreIds: nil,
        keywords: "15060",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.2,
        voteCountMin: 100,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [27, 35, 878, 53],
        minimumEvidenceScore: 18,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "K-Drama Corner",
        subtitle: "Korean series that fit your taste profile",
        mediaType: "tv",
        genreIds: nil,
        keywords: nil,
        excludeGenres: nil,
        originalLanguage: "ko",
        originCountry: "KR",
        voteAverageMin: 7.0,
        voteCountMin: 40,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [18, 10749],
        minimumEvidenceScore: 18,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Adult Animation",
        subtitle: "Animation with sharper edges",
        mediaType: "tv",
        genreIds: "16",
        keywords: nil,
        excludeGenres: "10751",
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.7,
        voteCountMin: 60,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [16, 35, 10765],
        minimumEvidenceScore: 16,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Real Life Stories",
        subtitle: "True stories and grounded dramatic arcs",
        mediaType: "movie",
        genreIds: "18,36",
        keywords: "9672",
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.5,
        voteCountMin: 70,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [18, 36, 99],
        minimumEvidenceScore: 18,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Anime Picks",
        subtitle: "Japanese animation with stronger taste overlap",
        mediaType: "tv",
        genreIds: "16",
        keywords: nil,
        excludeGenres: nil,
        originalLanguage: "ja",
        originCountry: nil,
        voteAverageMin: 7.0,
        voteCountMin: 40,
        voteCountMax: nil,
        runtimeLte: nil,
        evidenceGenreIds: [16, 10765, 10759],
        minimumEvidenceScore: 16,
        sortBy: "popularity.desc"
      ),
      MicrogenreRule(
        title: "Underseen Picks Similar to Your Favorites",
        subtitle: "Lower-profile titles with real taste overlap",
        mediaType: "movie",
        genreIds: nil,
        keywords: nil,
        excludeGenres: nil,
        originalLanguage: nil,
        originCountry: nil,
        voteAverageMin: 6.5,
        voteCountMin: 40,
        voteCountMax: 1200,
        runtimeLte: nil,
        evidenceGenreIds: [18, 53, 878, 9648, 35, 80],
        minimumEvidenceScore: 24,
        sortBy: "popularity.desc"
      )
    ]
  }
}
