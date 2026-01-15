import Foundation

/// A Sendable Data Transfer Object for Title.
/// This struct is used to transfer data across actor boundaries (e.g. background fetch to MainActor)
/// to avoid concurrency warnings with SwiftData's non-Sendable @Model classes.
struct TitleDTO: Codable, Sendable, Identifiable {
    var id: Int?
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
    var numberOfSeasons: Int?
    var mediaType: String?
}

struct TMDBAPIObjectDTO: Decodable {
    var results: [TitleDTO] = []
}
