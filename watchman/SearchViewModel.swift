import Foundation
import Observation

@Observable
class SearchViewModel {
  var searchTitles: [Title] = []
  var searchPeople: [Person] = []
  var errorMessage: String? = nil

  private let dataFetcher = DataFetcher()

  // MARK: - Intents

  func getSearchTitles(by endpoint: String, for query: String) async {
    guard !query.isEmpty else { return }

    // Fetch titles and people in parallel
    async let titlesTask = fetchTitles(query: query)
    async let peopleTask = fetchPeople(query: query)

    let (titlesDTOs, people) = await (titlesTask, peopleTask)

    await MainActor.run {
      self.searchTitles = titlesDTOs.map { Title(dto: $0) }
      self.searchPeople = people
    }
  }

  private func fetchTitles(query: String) async -> [TitleDTO] {
    do {
      let fetched = try await dataFetcher.fetchTitlesDTO(for: "multi", by: "search", with: query)
      return fetched.filter {
        ($0.mediaType == "movie" || $0.mediaType == "tv" || $0.mediaType == nil) &&
        $0.posterPath != nil && !$0.posterPath!.isEmpty
      }
    } catch {
      print("Error fetching titles: \(error)")
      return []
    }
  }

  private func fetchPeople(query: String) async -> [Person] {
    do {
      let fetched = try await dataFetcher.fetchSearchPeople(query: query)
      return fetched.filter { $0.profilePath != nil && !$0.profilePath!.isEmpty }
    } catch {
      print("Error fetching people: \(error)")
      return []
    }
  }

  func clearResults() {
    searchTitles = []
    searchPeople = []
    errorMessage = nil
  }
}
