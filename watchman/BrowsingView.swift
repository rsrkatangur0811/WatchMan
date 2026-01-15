import SwiftUI

@available(iOS 26.0, *)
struct BrowsingView: View {
  let title: String
  let endpoint: String  // e.g., "popular", "top_rated", "upcoming"
  let mediaType: String  // "movie" or "tv"

  @State private var titles: [Title] = []
  @State private var isLoading = true
  private let dataFetcher = DataFetcher()

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
      } else {
        VerticalListView(titles: titles, canDelete: false)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      do {
        let fetched = try await dataFetcher.fetchTitles(for: mediaType, by: endpoint)
        titles = fetched.filter { ($0.voteAverage ?? 0) < 10.0 }
      } catch {
        print("Failed to fetch browsing titles: \(error)")
      }
      isLoading = false
    }
  }
}
