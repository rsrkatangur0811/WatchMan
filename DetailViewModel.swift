import Foundation
import SwiftUI

@MainActor
@Observable
class DetailViewModel {
  enum LoadStatus {
    case loading
    case success
    case failed(Error)
  }

  var state: LoadStatus = .success

  var title: Title
  var cast: [Cast] = []
  var crew: [Crew] = []
  var reviews: [Review] = []
  var videos: [Video] = []
  var recommendations: [Title] = []
  var providers: [ProviderItem] = []
  var productionCompanies: [ProductionCompany] = []

  var directorCredits: [Title] = []
  var directorName: String?
  var collectionTitles: [Title] = []

  // TV Specific
  var selectedSeason: Title.Season?
  var episodes: [Title.Episode] = []

  // DataFetcher is a struct (value type), likely Sendable. If not, we might need to be careful.
  // Assuming DataFetcher is Sendable (structs usually are if properties are).
  private let dataFetcher = DataFetcher()

  init(title: Title) {
    self.title = title
  }

  var isReleased: Bool {
    guard let releaseDate = title.releaseDate else { return true } // Assume released if no date? Or unreleased? 
    // Usually API returns future dates for upcoming. Missing date often means old/unknown.
    // Let's assume true if missing, but check date if present.
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: releaseDate) else { return true }
    return date <= Date()
  }

  // Internal storage for base series cast
  private var seriesCast: [Cast] = []

  func loadAllData() async {
    guard let id = title.id else { return }
    let mediaType = title.name != nil ? "tv" : "movie"

    do {
      // SINGLE MEGA-CALL: Fetches title + credits + videos + reviews + recommendations + providers
      let response = try await TMDBClient.shared.fetchFullTitle(id: id, mediaType: mediaType)

      // Apply title data
      self.title = response.toTitle()

      // Apply certification
      self.title.certification = response.extractCertification()

      // Apply credits
      self.seriesCast = response.credits?.cast ?? []
      self.cast = self.seriesCast
      self.crew = response.credits?.crew ?? []

      // Apply videos
      self.videos = (response.videos?.results ?? []).filter {
        $0.isTrailer
      }

      // Apply reviews
      self.reviews = response.reviews?.results ?? []

      // Apply recommendations
      let rawRecs = response.recommendations?.results ?? []
      self.recommendations = self.filterTitles(rawRecs)

      // Apply providers (India)
      self.providers = response.extractProviders()
      self.productionCompanies = response.productionCompanies ?? []

      // Fetch real external ratings from OMDB
      // First get the IMDB ID from TMDB's external_ids endpoint
      Task { [weak self] in
        await self?.fetchExternalRatings(id: id, mediaType: mediaType)
      }

      Task { [weak self] in
        await self?.fetchLetterboxdRating(id: id, mediaType: mediaType)
      }

      state = .success

      // SECONDARY CALL: Fetch director credits
      if let director = self.crew.first(where: { $0.job == "Director" }) {
        self.directorName = director.name
        Task { [weak self] in
          guard let self else { return }
          do {
            let credits = try await TMDBClient.shared.fetchDirectorCredits(personId: director.id)
            self.directorCredits = self.filterTitles(credits)
          } catch {
            print("Director credits failed: \(error)")
          }
        }
      } else if let creator = self.crew.first(where: {
        $0.job == "Executive Producer" || $0.job == "Creator"
      }) {
        self.directorName = creator.name
        Task { [weak self] in
          guard let self else { return }
          do {
            let credits = try await TMDBClient.shared.fetchDirectorCredits(personId: creator.id)
            self.directorCredits = self.filterTitles(credits)
          } catch {
            print("Creator credits failed: \(error)")
          }
        }
      }

      // THIRD CALL: Fetch collection (series) parts
      if let collection = self.title.belongsToCollection {
        print("DEBUG: Found collection for title: \(collection.name) (ID: \(collection.id))")
        Task { [weak self] in
          guard let self else { return }
          do {
            let parts = try await TMDBClient.shared.fetchCollectionDetails(id: collection.id)
            print("DEBUG: Fetched \(parts.count) parts for collection \(collection.id)")
            // Filter out current movie
            let filtered = self.filterTitles(parts).filter { $0.id != self.title.id }
            print("DEBUG: Filtered parts count: \(filtered.count)")
            self.collectionTitles = filtered
          } catch {
            print("Collection fetch failed: \(error)")
          }
        }
      } else {
        print("DEBUG: No collection found for title: \(self.title.title ?? "Unknown")")
      }

    } catch {
      print("Failed to load title details: \(error)")
      state = .failed(error)
    }
  }

  func selectSeason(_ season: Title.Season) {
    guard let id = title.id else { return }
    self.selectedSeason = season

    Task { [weak self] in
      guard let self else { return }
      do {
        // Use TMDBClient with caching for season details + cast
        let (episodes, seasonCast) = try await TMDBClient.shared.fetchSeasonDetails(
          tvId: id, seasonNumber: season.seasonNumber)

        self.episodes = episodes

        // Merge Logic: Series Cast + Unique Season Cast
        // We prioritize series cast billing order, then append new faces from this season
        var merged = self.seriesCast
        let existingIds = Set(merged.map { $0.id })

        for actor in seasonCast {
          if !existingIds.contains(actor.id) {
            merged.append(actor)
          }
        }

        // Update main cast list
        self.cast = merged

      } catch {
        print("Failed to fetch episodes/cast for season \(season.seasonNumber): \(error)")
      }
    }
  }

  // MARK: - Helper to filter out invalid/10.0 rated items
  private func filterTitles(_ titles: [Title]) -> [Title] {
    return titles.filter { ($0.voteAverage ?? 0) < 10.0 }
  }

  // MARK: - External Ratings (OMDB)

  /// Fetches real IMDB and Rotten Tomatoes ratings from OMDB
  private func fetchExternalRatings(id: Int, mediaType: String) async {
    do {
      // Step 1: Get IMDB ID from TMDB
      let externalIDs = try await TMDBClient.shared.fetchExternalIDs(id: id, mediaType: mediaType)

      guard let imdbID = externalIDs.imdbId, !imdbID.isEmpty else {
        print("No IMDB ID available for \(mediaType)/\(id)")
        return
      }

      self.title.imdbID = imdbID

      // Step 2: Fetch ratings from OMDB
      guard let omdbResponse = await OMDBClient.shared.fetchRatings(imdbID: imdbID) else {
        print("Failed to fetch OMDB ratings for \(imdbID)")
        return
      }

      // Step 3: Map OMDB data to Title
      if let imdbScore = omdbResponse.imdbScore {
        self.title.imdbRating = imdbScore
      }

      if let critics = omdbResponse.rottenTomatoesCritics {
        self.title.criticsScore = critics
      }

      if let tomatoURL = omdbResponse.tomatoURL,
        let url = URL(string: tomatoURL),
        let rottenTomatoesScores = await RottenTomatoesClient.shared.fetchScores(url: url)
      {
        if let critics = rottenTomatoesScores.critics {
          self.title.criticsScore = critics
        }
        if let audience = rottenTomatoesScores.audience {
          self.title.audienceScore = audience
        }
      }

    } catch {
      print("Failed to fetch external ratings: \(error)")
    }
  }

  // MARK: - Letterboxd Rating

  private func fetchLetterboxdRating(id: Int, mediaType: String) async {
    guard let score = await LetterboxdClient.shared.fetchAverageRating(
      tmdbId: id,
      mediaType: mediaType
    ) else {
      return
    }

    self.title.letterboxdScore = score
  }
}
