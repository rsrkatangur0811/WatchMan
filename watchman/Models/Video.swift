import Foundation

struct VideoResponse: Decodable {
  let id: Int?  // Optional for appended responses
  let results: [Video]
}

struct Video: Decodable, Identifiable {
  let id: String
  let key: String
  let name: String
  let site: String
  let type: String

  var youtubeURL: URL? {
    guard site == "YouTube" else { return nil }
    return URL(string: "https://www.youtube.com/watch?v=\(key)")
  }
}
