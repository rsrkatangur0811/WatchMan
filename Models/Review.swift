import Foundation

struct ReviewResponse: Decodable {
  let id: Int?  // Optional for appended responses
  let page: Int?  // Optional for appended responses
  let results: [Review]
}

struct Review: Decodable, Identifiable {
  let id: String
  let author: String
  let content: String
  let createdAt: String
  let url: String?

}
