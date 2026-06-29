import SwiftUI

struct AttributeResultsView: View {
  let title: String
  let attributeValue: String
  let attributeType: AttributeType

  enum AttributeType {
    case country
    case language
  }

  @State private var selectedSort: SortOption = .defaults
  @State private var isMovies = true
  @State private var titles: [Title] = []
  @State private var isLoading = true
  private let dataFetcher = DataFetcher()
  @State private var currentPage = 1
  @State private var isFetchingMore = false
  @State private var hasMorePages = true
  @State private var showTopBlur = false
  @Namespace private var heroTransition
  @State private var selectedTitle: Title?
  @State private var tappedSourceID: String = ""

  var body: some View {
    ZStack {
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
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: columns, spacing: 12) {
              ForEach(titles.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }, id: \.stableDisplayID) {
                title in
                let sourceID = "attrResult_\(title.stableDisplayID)"
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
                    Task { await loadMoreContent() }
                  }
                }
              }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            if isFetchingMore {
              ProgressView().padding()
            }
          } header: {
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
      var fetched: [Title] = []
      let media = isMovies ? "movie" : "tv"

      switch attributeType {
      case .country:
        fetched = try await dataFetcher.fetchTitles(
          for: media,
          by: "discover",
          originCountry: attributeValue,
          voteCountMin: minVotes,
          sortBy: selectedSort.apiValue(mediaType: "movie"),
          page: currentPage
        )
      case .language:
        fetched = try await dataFetcher.fetchTitles(
          for: media,
          by: "discover",
          originalLanguage: attributeValue,
          voteCountMin: minVotes,
          sortBy: selectedSort.apiValue(mediaType: "tv"),
          page: currentPage
        )
      }

      let newTitles = fetched.filter { ($0.voteAverage ?? 0) < 10.0 }  // Basic filter

      if newTitles.isEmpty {
        hasMorePages = false
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
      print("Error fetching attribute results: \(error)")
    }

    isFetchingMore = false
  }
}
