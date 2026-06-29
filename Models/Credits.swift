import Foundation

struct CreditsResponse: Decodable {
  let id: Int?  // Optional for appended responses
  let cast: [Cast]
  let crew: [Crew]
}

struct Cast: Decodable, Identifiable {
  let id: Int
  let name: String
  let character: String?
  let profilePath: String?

  var profileURL: URL? {
    guard let profilePath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/h632\(profilePath)")
  }
}

struct Crew: Decodable, Identifiable {
  let id: Int
  let name: String
  let job: String
  let department: String
  let profilePath: String?

  var profileURL: URL? {
    guard let profilePath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/h632\(profilePath)")
  }
}
