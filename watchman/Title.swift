import Foundation
import SwiftData

@Model
class Title: Decodable, Identifiable, Hashable {
  @Attribute(.unique) var id: Int?
  var title: String?
  var name: String?
  var overview: String?
  var posterPath: String?
  var backdropPath: String?
  var runtime: Int?
  var budget: Int?
  var revenue: Int?
  var releaseDate: String?
  var status: String?
  var voteAverage: Double?
  var voteCount: Int?
  var genres: [Genre]?
  var numberOfSeasons: Int?
  var seasons: [Season]?
  var mediaType: String?

  // Credit specific fields
  var character: String?
  var job: String?
  var department: String?

  // Collection
  var belongsToCollection: Collection?

  struct Collection: Codable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?
  }

  // External Ratings
  var criticsScore: Int?
  var audienceScore: Int?
  var letterboxdScore: Double?

  // Images (Logos)
  var images: TitleImages?

  struct TitleImages: Codable, Hashable {
    let logos: [ImageInfo]?
    let backdrops: [ImageInfo]?
  }

  struct ImageInfo: Codable, Hashable {
    let filePath: String
    let aspectRatio: Double?
    let width: Int?
    let height: Int?
    let iso6391: String?
    let voteAverage: Double?
  }

  init(
    id: Int? = nil, title: String? = nil, name: String? = nil, overview: String? = nil,
    posterPath: String? = nil, backdropPath: String? = nil, runtime: Int? = nil, budget: Int? = nil,
    revenue: Int? = nil, releaseDate: String? = nil, status: String? = nil,
    voteAverage: Double? = nil, voteCount: Int? = nil, genres: [Genre]? = nil,
    numberOfSeasons: Int? = nil, seasons: [Season]? = nil, images: TitleImages? = nil,
    belongsToCollection: Collection? = nil
  ) {
    self.id = id
    self.title = title
    self.name = name
    self.overview = overview
    self.posterPath = posterPath
    self.backdropPath = backdropPath
    self.runtime = runtime
    self.budget = budget
    self.revenue = revenue
    self.releaseDate = releaseDate
    self.status = status
    self.voteAverage = voteAverage
    self.voteCount = voteCount
    self.genres = genres
    self.numberOfSeasons = numberOfSeasons
    self.seasons = seasons
    self.images = images
    self.belongsToCollection = belongsToCollection
  }

  convenience init(dto: TitleDTO) {
    self.init(
        id: dto.id,
        title: dto.title,
        name: dto.name,
        overview: dto.overview,
        posterPath: dto.posterPath,
        backdropPath: dto.backdropPath,
        runtime: dto.runtime,
        budget: dto.budget,
        revenue: dto.revenue,
        releaseDate: dto.releaseDate,
        status: dto.status,
        voteAverage: dto.voteAverage,
        voteCount: dto.voteCount,
        numberOfSeasons: dto.numberOfSeasons
    )
    self.mediaType = dto.mediaType
  }

  var posterURL: URL? {
    guard let posterPath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")
  }

  var certification: String?
  var createdBy: [Creator]?

  struct Creator: Codable, Hashable {
    let id: Int
    let name: String
  }

  enum CodingKeys: String, CodingKey {
    case id, title, name, overview, posterPath, backdropPath, runtime, budget, revenue, releaseDate,
      firstAirDate, status, character, job, department
    case voteAverage, voteCount, genres, numberOfSeasons, seasons, images, mediaType, createdBy
    case belongsToCollection
    case releaseDates
    case contentRatings
  }

  struct ReleaseDates: Decodable {
    let results: [ReleaseDateResult]
  }

  struct ReleaseDateResult: Decodable {
    let iso_3166_1: String
    let release_dates: [ReleaseDateDetail]
  }

  struct ReleaseDateDetail: Decodable {
    let certification: String
    let type: Int
  }

  struct ContentRatings: Decodable {
    let results: [ContentRatingResult]
  }

  struct ContentRatingResult: Decodable {
    let iso_3166_1: String
    let rating: String
  }

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(Int.self, forKey: .id)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    overview = try container.decodeIfPresent(String.self, forKey: .overview)
    posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
    backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
    budget = try container.decodeIfPresent(Int.self, forKey: .budget)
    revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
    releaseDate =
      try
      (container.decodeIfPresent(String.self, forKey: .releaseDate)
      ?? container.decodeIfPresent(String.self, forKey: .firstAirDate))
    status = try container.decodeIfPresent(String.self, forKey: .status)
    voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
    voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
    genres = try container.decodeIfPresent([Genre].self, forKey: .genres)
    numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
    seasons = try container.decodeIfPresent([Season].self, forKey: .seasons)
    images = try container.decodeIfPresent(TitleImages.self, forKey: .images)
    mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    character = try container.decodeIfPresent(String.self, forKey: .character)
    job = try container.decodeIfPresent(String.self, forKey: .job)
    department = try container.decodeIfPresent(String.self, forKey: .department)
    createdBy = try container.decodeIfPresent([Creator].self, forKey: .createdBy)
    belongsToCollection = try container.decodeIfPresent(Collection.self, forKey: .belongsToCollection)

    // Certification is now fetched via separate API calls in DetailViewModel
  }
  struct Genre: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
  }

  struct Season: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int?
    let posterPath: String?

    // For UI Display
    var posterURL: URL? {
      guard let posterPath else { return nil }
      return URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")
    }
  }

  struct Episode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let episodeNumber: Int?
    let airDate: String?
    let seasonNumber: Int?

    var stillURL: URL? {
      guard let stillPath else { return nil }
      return URL(string: "https://image.tmdb.org/t/p/w500\(stillPath)")
    }
  }

  static var previewTitles = [
    Title(
      id: 1, title: "BeetleJuice", name: "BeetleJuice", overview: "A movie about BeetleJuice",
      posterPath: Constants.testTitleURL, voteAverage: 8.5, voteCount: 1200),
    Title(
      id: 2, title: "Pulp Fiction", name: "Pulp Fiction", overview: "A movie about Pulp Fiction",
      posterPath: Constants.testTitleURL2, voteAverage: 9.2, voteCount: 3500),
    Title(
      id: 3, title: "The Dark Knight", name: "The Dark Knight",
      overview: "A movie about the Dark Knight", posterPath: Constants.testTitleURL3,
      voteAverage: 9.8, voteCount: 5000),
  ]
}

struct TMDBAPIObject: Decodable {
  var results: [Title] = []
}

struct SeasonDetailResponse: Decodable {
  let id: Int?
  let episodes: [Title.Episode]?
  let credits: CreditsResponse?
}

// MARK: - Combined Response for Mega-call

/// Response model for combined TMDB fetch with append_to_response
/// Decodes title details + credits, videos, reviews, recommendations, providers in one call
struct TitleDetailResponse: Decodable {
  // Core title data (decoded from root)
  let id: Int?
  let title: String?
  let name: String?
  let overview: String?
  let posterPath: String?
  let backdropPath: String?
  let runtime: Int?
  let budget: Int?
  let revenue: Int?
  let releaseDate: String?
  let firstAirDate: String?
  let status: String?
  let voteAverage: Double?
  let voteCount: Int?
  let genres: [Title.Genre]?
  let numberOfSeasons: Int?
  let seasons: [Title.Season]?
  let images: Title.TitleImages?
  let mediaType: String?
  let createdBy: [Title.Creator]?
  let belongsToCollection: Title.Collection?

  // Appended data
  let credits: CreditsResponse?
  let videos: VideoResponse?
  let reviews: ReviewResponse?
  let recommendations: TMDBAPIObject?
  let releaseDates: ReleaseDatesWrapper?
  let contentRatings: ContentRatingsWrapper?

  // Watch providers - uses special key
  enum CodingKeys: String, CodingKey {
    case id, title, name, overview, posterPath, backdropPath, runtime, budget, revenue
    case releaseDate, firstAirDate, status, voteAverage, voteCount, genres
    case numberOfSeasons, seasons, images, mediaType, createdBy
    case belongsToCollection
    case credits, videos, reviews, recommendations
    case releaseDates
    case contentRatings
    case watchProviders = "watch/providers"
  }

  // Nested providers response
  let watchProviders: ProviderResponse?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Core fields
    id = try container.decodeIfPresent(Int.self, forKey: .id)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    overview = try container.decodeIfPresent(String.self, forKey: .overview)
    posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
    backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
    budget = try container.decodeIfPresent(Int.self, forKey: .budget)
    revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
    releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
    firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
    status = try container.decodeIfPresent(String.self, forKey: .status)
    voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
    voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
    genres = try container.decodeIfPresent([Title.Genre].self, forKey: .genres)
    numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
    seasons = try container.decodeIfPresent([Title.Season].self, forKey: .seasons)
    images = try container.decodeIfPresent(Title.TitleImages.self, forKey: .images)
    mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    createdBy = try container.decodeIfPresent([Title.Creator].self, forKey: .createdBy)
    belongsToCollection = try container.decodeIfPresent(Title.Collection.self, forKey: .belongsToCollection)

    // Appended data
    credits = try container.decodeIfPresent(CreditsResponse.self, forKey: .credits)
    videos = try container.decodeIfPresent(VideoResponse.self, forKey: .videos)
    reviews = try container.decodeIfPresent(ReviewResponse.self, forKey: .reviews)
    recommendations = try container.decodeIfPresent(TMDBAPIObject.self, forKey: .recommendations)

    releaseDates = try container.decodeIfPresent(ReleaseDatesWrapper.self, forKey: .releaseDates)
    contentRatings = try container.decodeIfPresent(
      ContentRatingsWrapper.self, forKey: .contentRatings)
    watchProviders = try container.decodeIfPresent(ProviderResponse.self, forKey: .watchProviders)
  }

  // Helper to convert to Title model
  func toTitle() -> Title {
    let t = Title(
      id: id, title: title, name: name, overview: overview,
      posterPath: posterPath, backdropPath: backdropPath, runtime: runtime, budget: budget,
      revenue: revenue, releaseDate: releaseDate ?? firstAirDate, status: status,
      voteAverage: voteAverage, voteCount: voteCount, genres: genres,
      numberOfSeasons: numberOfSeasons, seasons: seasons, images: images
    )
    t.mediaType = mediaType
    t.createdBy = createdBy
    t.belongsToCollection = belongsToCollection
    return t
  }

  // Extract certification from appended data
  func extractCertification() -> String {
    // For movies - use release_dates
    if let releaseDates = releaseDates?.results {
      // Prefer US
      if let us = releaseDates.first(where: { $0.iso31661 == "US" }) {
        if let cert = us.releaseDates.first(where: {
          ($0.type == 3 || $0.type == 4) && !$0.certification.isEmpty
        })?.certification {
          return cert
        }
        if let cert = us.releaseDates.first(where: { !$0.certification.isEmpty })?.certification {
          return cert
        }
      }
      // Fallback to any
      if let cert = releaseDates.flatMap({ $0.releaseDates }).first(where: {
        !$0.certification.isEmpty
      })?.certification {
        return cert
      }
    }

    // For TV - use content_ratings
    if let contentRatings = contentRatings?.results {
      if let us = contentRatings.first(where: { $0.iso31661 == "US" && !$0.rating.isEmpty }) {
        return us.rating
      }
      if let any = contentRatings.first(where: { !$0.rating.isEmpty }) {
        return any.rating
      }
    }

    return "NR"
  }

  // Extract providers for India
  func extractProviders() -> [ProviderItem] {
    guard let providers = watchProviders?.results["IN"]?.flatrate else { return [] }
    return providers.sorted { $0.displayPriority < $1.displayPriority }
  }
}

// MARK: - Helper Wrappers for nested certification data

struct ReleaseDatesWrapper: Decodable {
  let results: [ReleaseDateCountry]

  struct ReleaseDateCountry: Decodable {
    let iso31661: String
    let releaseDates: [ReleaseDate]
  }

  struct ReleaseDate: Decodable {
    let certification: String
    let type: Int
  }
}

struct ContentRatingsWrapper: Decodable {
  let results: [ContentRating]

  struct ContentRating: Decodable {
    let iso31661: String
    let rating: String
  }
}
