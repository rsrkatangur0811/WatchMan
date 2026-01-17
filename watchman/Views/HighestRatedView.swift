import SwiftUI

@available(iOS 26.0, *)
struct HighestRatedView: View {
  @State private var isMovies = true
  @State private var titles: [Title] = []
  @State private var isLoading = true
  @State private var showTopBlur = false
  @State private var currentPage = 1
  @State private var isFetchingMore = false
  @State private var hasMorePages = true

  @Namespace private var heroTransition
  @State private var selectedTitle: Title?
  @State private var tappedSourceID: String = ""

  private let dataFetcher = DataFetcher()

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
              ForEach(titles.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }) { title in
                let sourceID = "toprated_\(title.id ?? 0)"
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
                  // Trigger loading more when reaching near the end
                  if title.id == titles.suffix(6).first?.id && hasMorePages && !isFetchingMore {
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
                .tint(.white)
                .padding()
            }
          } header: {
            FilterPillBar(isMovies: $isMovies, showGlass: showTopBlur)
              .padding(.horizontal)
              .padding(.vertical, 10)
          }
        }
      }
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { _, newValue in
        withAnimation {
          showTopBlur = newValue > 0
        }
      }
      
      if isLoading && titles.isEmpty {
        ProgressView()
          .tint(.white)
      }
    }
    .navigationTitle("Highest Rated")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $selectedTitle) { title in
      TitleDetailView(title: title)
        .navigationTransition(.zoom(sourceID: tappedSourceID, in: heroTransition))
    }
    .onChange(of: isMovies) { _, _ in
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.impactOccurred()
      titles = []
      currentPage = 1
      hasMorePages = true
      isFetchingMore = false
      Task {
        await loadMoreContent()
      }
    }
    .task {
      if titles.isEmpty {
        await loadMoreContent()
      }
    }
  }

  /// Loads next page of content using top_rated endpoint
  private func loadMoreContent() async {
    guard !isFetchingMore else { return }
    isFetchingMore = true
    
    if titles.isEmpty {
      isLoading = true
    }

    do {
      let fetched = try await dataFetcher.fetchTitles(
        for: isMovies ? "movie" : "tv",
        by: "top_rated",
        page: currentPage
      )

      if fetched.isEmpty {
        hasMorePages = false
      } else {
        let newTitles = fetched.filter { 
          ($0.voteAverage ?? 0) < 10.0 && 
          $0.posterPath != nil && 
          !$0.posterPath!.isEmpty
        }
        
        if newTitles.isEmpty {
          // All filtered out, try next page
          currentPage += 1
          isFetchingMore = false
          await loadMoreContent()
          return
        }
        
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

    isLoading = false
    isFetchingMore = false
  }
}
