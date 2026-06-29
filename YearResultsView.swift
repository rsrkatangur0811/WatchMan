import SwiftUI

struct YearResultsView: View {
  let title: String
  let year: Int?
  let decade: Int?  // Optional, if "Any" is selected we filter by decade (logic needed or just show all popular?)
  // For simplicity, if "Any" decade selected, we might just show simplified list or all from that decade.
  // API discover allows range like primary_release_date.gte & lte.
  // DataFetcher currently only supports specific year.
  @State private var selectedSort: SortOption = .defaults

  // ... (existing properties)

  // Note: Add this property wrapper below the others to not break existing layout
  // But wait, replace_file_content is better done by sections.
  // I will just rewrite the body logic mostly.

  @State private var isMovies = true
  @State private var titles: [Title] = []
  @State private var isLoading = true
  private let dataFetcher = DataFetcher()
  @State private var navigationPath = NavigationPath()
  @State private var currentPage = 1
  @State private var isFetchingMore = false
  @State private var hasMorePages = true

  @State private var showTopBlur = false
  @Namespace private var heroTransition
  @State private var selectedTitle: Title?
  @State private var tappedSourceID: String = ""

  var body: some View {
    ZStack {
      // ... (background logic unchanged)
      Color.black.ignoresSafeArea()
      LinearGradient(
        gradient: Gradient(colors: [Color.black, Color.white.opacity(0.15)]),
        startPoint: .top,
        endPoint: UnitPoint(x: 0.5, y: 1.2)
      )
      .ignoresSafeArea()

      ScrollView {
        LazyVStack(pinnedViews: [.sectionHeaders]) {
          Section {
            // Grid for poster cards
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: columns, spacing: 12) {
              // Filter out titles without posters
              ForEach(titles.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }, id: \.stableDisplayID) {
                title in
                let sourceID = "yearResult_\(title.stableDisplayID)"
                PosterCard(
                  title: title, width: nil, height: nil, namespace: heroTransition,
                  sourceID: sourceID, showBorder: true
                )
                .aspectRatio(2 / 3, contentMode: .fit)
                .onTapGesture {
                  tappedSourceID = sourceID
                  selectedTitle = title
                }
                .onAppear {
                  if title.id == titles.last?.id && hasMorePages && !isFetchingMore {
                    Task {
                      await loadMoreContent()
                    }
                  }
                }
              }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            if isFetchingMore {
              ProgressView()
                .padding()
            }
          } header: {
            // Custom Pill Filter Bar
	            FilterPillBar(isMovies: $isMovies, showGlass: showTopBlur)
              .padding(.horizontal)
              .padding(.vertical, 10)
          }
        }
      }
      .scrollEdgeEffectSoftCompat(for: .top)
      .compatibleOnScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showTopBlur = newValue > 0
        }
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .appNavigationBackButton()
    .navigationDestination(item: $selectedTitle) { title in
      TitleDetailView(title: title)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Picker("Sort By", selection: $selectedSort) {
            ForEach(SortOption.allCases) { option in
              Label(option.rawValue, systemImage: option.icon).tag(option)
            }
          }
        } label: {
          Image(systemName: selectedSort.icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(minWidth: 54)
            .frame(height: 38)
            .accessibilityLabel("Sort By")
        }
      }
    }
    .onChange(of: selectedSort) { _, _ in
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.impactOccurred()
      titles = []
      currentPage = 1
      hasMorePages = true
      isFetchingMore = false
      fetchTitles()
    }
    .onChange(of: isMovies) { _, _ in
      titles = []
      currentPage = 1
      hasMorePages = true
      isFetchingMore = false
      fetchTitles()
    }
    .task {
      if titles.isEmpty {
        fetchTitles()
      }
    }
  }

  // Load Content Helpers
  private func fetchTitles() {
    isLoading = true
    Task {
      await loadMoreContent()
      isLoading = false
    }
  }

  private func loadMoreContent() async {
    guard !isFetchingMore else { return }
    isFetchingMore = true

    // For rating sort, require minimum votes to avoid spam
    let minVotes: Int? = selectedSort == .rating ? 200 : nil

    do {
      let fetched: [Title]
      if let year = year {
        fetched = try await dataFetcher.fetchTitles(
          for: isMovies ? "movie" : "tv", by: "discover", year: year,
          voteCountMin: minVotes, sortBy: selectedSort.apiValue(mediaType: "movie"), page: currentPage)
      } else if let decade = decade {
        let gte = "\(decade)-01-01"
        let lte = "\(decade + 9)-12-31"
        fetched = try await dataFetcher.fetchTitles(
          for: isMovies ? "movie" : "tv", by: "discover",
          voteCountMin: minVotes, releaseDateGte: gte, releaseDateLte: lte,
          sortBy: selectedSort.apiValue(mediaType: "movie"), page: currentPage)
      } else {
        fetched = try await dataFetcher.fetchTitles(
          for: isMovies ? "movie" : "tv", by: "discover",
          voteCountMin: minVotes, sortBy: selectedSort.apiValue(mediaType: "tv"), page: currentPage)
      }
      
      let newTitles = fetched.filter { ($0.voteAverage ?? 0) < 10.0 && $0.posterPath != nil && !$0.posterPath!.isEmpty }

      if fetched.isEmpty {
        hasMorePages = false
      } else if newTitles.isEmpty {
        // We received data but filtered it all out (e.g. no posters). 
        // Automatically fetch next page so user doesn't see a blank screen or get stuck.
        currentPage += 1
        await loadMoreContent()
        return
      } else {
        let existingIds = Set(titles.compactMap { $0.id })
        let uniqueNew = newTitles.filter { title in
          guard let id = title.id else { return true }
          return !existingIds.contains(id)
        }

        titles.append(contentsOf: uniqueNew)
        currentPage += 1
      }
    } catch {
      print("Error fetching page \(currentPage): \(error)")
    }

    isFetchingMore = false
  }
}
