import Foundation

struct Person: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String
  let profilePath: String?
  let knownForDepartment: String?

  var profileURL: URL? {
    guard let profilePath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/h632\(profilePath)")
  }
}

struct PersonDetail: Decodable, Identifiable {
  let id: Int
  let name: String
  let profilePath: String?
  let knownForDepartment: String?
  let biography: String?
  let birthday: String?
  let deathday: String?
  let placeOfBirth: String?

  var profileURL: URL? {
    guard let profilePath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/h632\(profilePath)")
  }

}

struct TrendingPersonResponse: Decodable {
  let results: [Person]
}
