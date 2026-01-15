import Foundation

struct ProviderResponse: Decodable {
  let id: Int?  // Optional for appended responses
  let results: [String: ProviderRegion]
}

struct ProviderRegion: Decodable {
  let link: String?
  let flatrate: [ProviderItem]?
  let rent: [ProviderItem]?
  let buy: [ProviderItem]?
}

struct ProviderItem: Decodable, Identifiable {
  let providerId: Int
  let providerName: String
  let logoPath: String?
  let displayPriority: Int

  var id: Int { providerId }

  var logoURL: URL? {
    guard let path = logoPath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/original\(path)")
  }
}
