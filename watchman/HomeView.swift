import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {

  @State private var viewModel = ViewModel()
  @State private var titleDetailPath = NavigationPath()
  @Environment(\.modelContext) var modelContext
  @State private var currentPosterColor: Color = .black
  @State private var webImageLoader = ImageLoader()
  @State private var showTopBlur = false
  @State private var selectedFilter: HomeFilter? = nil
  @Namespace private var animation
  @Namespace private var heroTransition
  @State private var selectedTitle: Title? = nil
  @State private var tappedSourceID: String = ""

  @State private var colorCache: [Int: Color] = [:]
  @State private var selectedSort: SortOption = .defaults
  @State private var showCategoryMenu: Bool = false
  
  // Search state
  @Binding var isSearchActive: Bool
  @State private var searchText: String = ""
  @State private var isSearching: Bool = false // Add loading state
  @State private var showSearchTopBlur: Bool = false // Scroll state for search header
  @State private var searchViewModel = SearchViewModel()
  @FocusState private var isSearchFieldFocused: Bool

  enum SortOption: String, CaseIterable, Identifiable {
    case defaults = "Default"
    case popularity = "Popularity"
    case name = "Name"
    case releaseDate = "Release Date"
    case rating = "Highest Rated"

    var id: String { rawValue }

    var icon: String {
      switch self {
      case .defaults: return "arrow.up.arrow.down"
      case .popularity: return "flame"
      case .name: return "textformat.abc"
      case .releaseDate: return "calendar"
      case .rating: return "star"
      }
    }
  }

  enum HomeFilter: Identifiable, Equatable, Hashable {
    case shows
    case movies
    case category(Genre, String? = nil)

    var id: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .category(let genre, _): return genre.name  // ID stable regardless of context? Maybe unique if context changes?
      }
    }

    // Helper to get raw string for display
    var displayTitle: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .category(let genre, _): return genre.name
      }
    }

    // Geometry ID for smooth transitions
    var geometryId: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .category: return "CategoryPill"
      }
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      // Dynamic Background Gradient
      ZStack {
        LinearGradient(
          gradient: Gradient(colors: [currentPosterColor.opacity(0.6), .black]),
          startPoint: .top,
          endPoint: UnitPoint(x: 0.5, y: 1.2)
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: currentPosterColor)
      }

      ScrollView(.vertical, showsIndicators: false) {
        switch viewModel.homeStatus {
        case .notStarted, .fetching:
          ProgressView()
            .frame(height: 300)
            .frame(maxWidth: .infinity)

        case .success:
          if let filter = selectedFilter, isCategoryFilter(filter) {
             // --- CATEGORY MODE: Flat Layout (Fixes Jumping) ---
             // Carousel + Sticky Header + Grid
             VStack(spacing: 0) {
                 categoryCarousel(for: filter)
                 
                 LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12, pinnedViews: [.sectionHeaders]) {
                     Section {
                         let titles = getCategoryTitles(for: filter)
                         ForEach(titles) { title in
                             let width = (UIScreen.main.bounds.width - 56) / 3
                             let height = width * 1.5
                             let sourceID = "categoryGrid_\(title.id ?? 0)"
                             
                             PosterCard(
                               title: title, width: width, height: height, namespace: heroTransition,
                               sourceID: sourceID, showBorder: true
                             )
                             .id(title.id) // Use stable ID, removed posterPath check to prevent recreation
                             .aspectRatio(2 / 3, contentMode: .fit)
                             .onTapGesture {
                               tappedSourceID = sourceID
                               selectedTitle = title
                             }
                             .onAppear {
                               if title.id == titles.last?.id {
                                 Task { await viewModel.loadMoreGenreContent() }
                               }
                             }
                         }
                     } header: {
                         sortHeader
                     }
                 }
                 .padding(.horizontal)
                 .padding(.bottom, 20)
                 .animation(nil, value: getCategoryTitles(for: filter).count) // Disable layout animation on append
             }
          } else {
             // --- STANDARD MODE: LazyVStack ---
             LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                if let filter = selectedFilter {
                  sectionsContent(for: filter)
                } else {
                  defaultContent
                }
             }
          }

        case .failed(let error):
          Text(error.localizedDescription)
            .foregroundStyle(.red)
        }
      }
      .safeAreaInset(edge: .top) {
        if !isSearchActive {
          headerView
        }
      }
      // .scrollTargetBehavior(.viewAligned)  // Helps with carousel snap if needed
      .ignoresSafeArea(edges: .top)
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showTopBlur = newValue > 20
        }
      }
      .overlay {
        if showCategoryMenu {
          FullScreenCategoryMenu(
            isPresented: $showCategoryMenu,
            selectedFilter: $selectedFilter,
            genres: availableGenres,
            onSelect: { genre in
              // Determine context from current filter state
              var context: String? = nil
              if let current = selectedFilter {
                if current == .movies {
                  context = "movie"
                } else if current == .shows {
                  context = "tv"
                }
                if case .category(_, let ctx) = current { context = ctx }
              }

              withAnimation(.snappy) {
                selectedFilter = .category(genre, context)
                // Pass current sort option
                Task { await viewModel.getGenreContent(for: genre.id(for: context), type: context, sortOption: selectedSort) }
              }
            }
          )
          .transition(.opacity)
          .zIndex(100)
        }
        

      }
      .navigationDestination(item: $selectedTitle) { title in
        TitleDetailView(title: title)
          .navigationTransition(.zoom(sourceID: tappedSourceID, in: heroTransition))
      }
      .toolbar(showCategoryMenu || isSearchActive ? .hidden : .visible, for: .tabBar)
      // Hide the CUSTOM Liquid Glass Tab Bar when searching
      .preference(key: TabBarVisibilityPreferenceKey.self, value: isSearchActive || showCategoryMenu)
      .navigationDestination(for: SectionData.self) { section in
        SectionResultsView(title: section.title, items: section.items)
      }
    }
    .task {
      // Only fetch if not already loaded (to avoid reset on back from detail)
      if viewModel.homeStatus == .notStarted {
        await viewModel.getTitles()
      }
    }
  }

  // MARK: - Subviews
  
  @ViewBuilder
  private func filteredContent(for filter: HomeFilter) -> some View {
    if isCategoryFilter(filter) {
      // Category Filter: Show grid layout
      categoryGridContent(for: filter)
    } else {
      // Movies/Shows Filter: Show horizontal sections
      sectionsContent(for: filter)
    }
  }

  @ViewBuilder
  private func sectionsContent(for filter: HomeFilter) -> some View {
    VStack(spacing: 10) {
      if shouldShowMovies(for: filter) {
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: 20) {
            ForEach(
              viewModel.inTheatresMovies.filter {
                $0.posterPath != nil && !$0.posterPath!.isEmpty
              }
            ) { title in
              let sourceID = "featured_movies_\(title.id ?? 0)"
              FeaturedCarouselItem(
                title: title,
                screenWidth: UIScreen.main.bounds.width,
                onUpdateColor: { title in
                  updateColor(for: title)
                },
                onSelect: { title in
                  tappedSourceID = sourceID
                  selectedTitle = title
                },
                namespace: heroTransition,
                sourceID: sourceID
              )
            }
          }
          .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 460)

        if !viewModel.popularMovies.isEmpty {
          SectionHeaderView(
            title: "Popular Movies",
            subtitle: "What everyone's watching",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "Popular Movies", items: viewModel.popularMovies))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.popularMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "popularMovies")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)  // Reduced padding
        }

        if !viewModel.upcomingMovies.isEmpty {
          SectionHeaderView(
            title: "New & Upcoming",
            subtitle: "Fresh arrivals",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "New & Upcoming", items: viewModel.upcomingMovies))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.upcomingMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "upcomingMovies")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // Top Rated Movies
        if !viewModel.topRatedMovies.isEmpty {
          SectionHeaderView(
            title: "Top Rated Movies",
            subtitle: "Critically acclaimed",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "Top Rated Movies", items: viewModel.topRatedMovies))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.topRatedMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "topRatedMovies")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // Dynamic Movie Sections
        ForEach(viewModel.movieSections) { section in
          SectionHeaderView(
            title: section.title,
            subtitle: section.subtitle,
            onTap: {
              titleDetailPath.append(SectionData(title: section.title, items: section.items))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(section.items.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }) {
                title in
                tappablePosterCard(title: title, section: "movieSection_\(section.title)")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }
      }

      if shouldShowShows(for: filter) {
        // Hero Carousel for TV Shows (Trending)
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: 20) {
            ForEach(
              Array(
                viewModel.trendingTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
                  .prefix(10))
            ) { title in
              let sourceID = "featured_tv_\(title.id ?? 0)"
              FeaturedCarouselItem(
                title: title,
                screenWidth: UIScreen.main.bounds.width,
                onUpdateColor: { title in
                  updateColor(for: title)
                },
                onSelect: { title in
                  tappedSourceID = sourceID
                  selectedTitle = title
                },
                namespace: heroTransition,
                sourceID: sourceID
              )
            }
          }
          .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 460)

        // 1. Trending TV (if not fully covered by Hero, or show remaining)
        // Actually, let's show "Popular Shows" first
        if !viewModel.popularTV.isEmpty {
          SectionHeaderView(
            title: "Popular Shows",
            subtitle: "Most watched series",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "Popular Shows", items: viewModel.popularTV))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.popularTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "popularTV")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // 2. Airing Today
        if !viewModel.airingTodayTV.isEmpty {
          SectionHeaderView(
            title: "Airing Today",
            subtitle: "New episodes available now",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "Airing Today", items: viewModel.airingTodayTV))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.airingTodayTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "airingTodayTV")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // 3. On The Air
        if !viewModel.onTheAirTV.isEmpty {
          SectionHeaderView(
            title: "On The Air",
            subtitle: "Currently airing seasons",
            onTap: {
              titleDetailPath.append(SectionData(title: "On The Air", items: viewModel.onTheAirTV))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.onTheAirTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "onTheAirTV")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // 4. Top Rated TV
        if !viewModel.topRatedTV.isEmpty {
          SectionHeaderView(
            title: "Top Rated TV",
            subtitle: "All-time favorites",
            onTap: {
              titleDetailPath.append(
                SectionData(title: "Top Rated TV", items: viewModel.topRatedTV))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(
                viewModel.topRatedTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
              ) { title in
                tappablePosterCard(title: title, section: "topRatedTV")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }

        // 5. Custom Categories (Dynamic)
        ForEach(viewModel.tvSections) { section in
          SectionHeaderView(
            title: section.title,
            subtitle: section.subtitle,
            onTap: {
              titleDetailPath.append(SectionData(title: section.title, items: section.items))
            }
          )
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 15) {
              ForEach(section.items.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }) {
                title in
                tappablePosterCard(title: title, section: "tvSection_\(section.title)")
              }
            }
            .padding(.horizontal)
          }
          .frame(height: 220)
          .padding(.bottom, 20)
        }
      }
    }
    .padding(.vertical, 20)
  }

  // Helpers to determine visibility based on filter context
  private func shouldShowMovies(for filter: HomeFilter) -> Bool {
    switch filter {
    case .shows: return false
    case .movies: return true
    case .category(_, let type): return type == nil || type == "movie"
    }
  }

  private func shouldShowShows(for filter: HomeFilter) -> Bool {
    switch filter {
    case .shows: return true
    case .movies: return false
    case .category(_, let type): return type == nil || type == "tv"
    }
  }

  private var availableGenres: [Genre] {
    let excludedIds = [53, 27, 10402] // Thriller, Horror, Music
    let isShowsMode = shouldShowShows(for: selectedFilter ?? .shows)

    if isShowsMode {
      return Genre.allGenres.filter { !excludedIds.contains($0.id) }
    } else {
      return Genre.allGenres
    }
  }

  @ViewBuilder
  private func categoryCarousel(for filter: HomeFilter) -> some View {
    if case .category(_, let type) = filter {
      if type == "movie" || type == nil {
        // Movies carousel
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: 20) {
            ForEach(
              viewModel.inTheatresMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
            ) { title in
              let sourceID = "category_movie_\(title.id ?? 0)"
              FeaturedCarouselItem(
                title: title,
                screenWidth: UIScreen.main.bounds.width,
                onUpdateColor: { title in updateColor(for: title) },
                onSelect: { title in
                  tappedSourceID = sourceID
                  selectedTitle = title
                },
                namespace: heroTransition,
                sourceID: sourceID
              )
            }
          }
          .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 460)
      } else {
        // Shows carousel
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: 20) {
            ForEach(
              Array(
                viewModel.trendingTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
                  .prefix(10))
            ) { title in
              let sourceID = "category_tv_\(title.id ?? 0)"
              FeaturedCarouselItem(
                title: title,
                screenWidth: UIScreen.main.bounds.width,
                onUpdateColor: { title in updateColor(for: title) },
                onSelect: { title in
                  tappedSourceID = sourceID
                  selectedTitle = title
                },
                namespace: heroTransition,
                sourceID: sourceID
              )
            }
          }
          .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 460)
      }
    }
  }

    // categoryGrid function removed/inlined to avoid nesting issues

  private var sortHeader: some View {
    HStack {
      Spacer()
      Menu {
        Picker("Sort By", selection: $selectedSort) {
          ForEach(SortOption.allCases) { option in
            Label(option.rawValue, systemImage: option.icon).tag(option)
          }
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: selectedSort.icon)
            .font(.system(size: 14, weight: .medium))
          Text(selectedSort.rawValue)
            .font(.netflixSans(.medium, size: 14))
          Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .onChange(of: selectedSort) { _, newSort in
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred()
          
          // Trigger API-side sort
          if case .category(let genre, let type) = selectedFilter {
             Task {
                 await viewModel.getGenreContent(for: genre.id(for: type), type: type, sortOption: newSort)
             }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
          if showTopBlur {
            Capsule()
              .fill(.clear)
              .glassEffect(.regular, in: .capsule)
          } else {
            Capsule()
              .fill(Color.white.opacity(0.1))
              .overlay(
                Capsule()
                  .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
              )
          }
        }
      }
      Spacer()
    }
    .padding(.vertical, 10)
    .background(Color.black.opacity(showTopBlur ? 0.0 : 0.0))  // Tap area fix maybe?
  }

  private func isCategoryFilter(_ filter: HomeFilter) -> Bool {
    if case .category = filter { return true }
    return false
  }

  private func getCategoryTitles(for filter: HomeFilter) -> [Title] {
    guard case .category(_, let type) = filter else { return [] }

    var titles: [Title] = []

    // When a category is selected, getGenreContent already filters the standard lists
    // So we just collect all available content
    if type == nil || type == "movie" {
      titles.append(contentsOf: viewModel.inTheatresMovies)
      titles.append(contentsOf: viewModel.popularMovies)
      titles.append(contentsOf: viewModel.upcomingMovies)
      titles.append(contentsOf: viewModel.topRatedMovies)
    }
    if type == nil || type == "tv" {
      titles.append(contentsOf: viewModel.trendingTV)
      titles.append(contentsOf: viewModel.popularTV)
      titles.append(contentsOf: viewModel.topRatedTV)
      titles.append(contentsOf: viewModel.airingTodayTV)
      titles.append(contentsOf: viewModel.onTheAirTV)
    }

    // Deduplicate by ID
    var seen = Set<Int>()
    return titles.filter { title in
      guard let id = title.id else { return false }
      if seen.contains(id) { return false }
      seen.insert(id)
      return title.posterPath != nil && !title.posterPath!.isEmpty
    }
  }

  // removed sortedTitles as sorting is now server-side

  @ViewBuilder
  private func categoryGridContent(for filter: HomeFilter) -> some View {
    let titles = getCategoryTitles(for: filter)
    // API sorting used
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    VStack(spacing: 0) {
      // Hero Carousel (Movies or Shows based on filter type)
      if case .category(_, let type) = filter {
        if type == "movie" || type == nil {
          // Movies carousel
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 20) {
              ForEach(
                viewModel.inTheatresMovies.filter {
                  $0.posterPath != nil && !$0.posterPath!.isEmpty
                }
              ) { title in
                let sourceID = "category_movie_\(title.id ?? 0)"
                FeaturedCarouselItem(
                  title: title,
                  screenWidth: UIScreen.main.bounds.width,
                  onUpdateColor: { title in updateColor(for: title) },
                  onSelect: { title in
                    tappedSourceID = sourceID
                    selectedTitle = title
                  },
                  namespace: heroTransition,
                  sourceID: sourceID
                )
              }
            }
            .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
            .scrollTargetLayout()
          }
          .scrollTargetBehavior(.viewAligned)
          .frame(height: 460)
        } else {
          // Shows carousel
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 20) {
              ForEach(
                Array(
                  viewModel.trendingTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
                    .prefix(10))
              ) { title in
                let sourceID = "category_tv_\(title.id ?? 0)"
                FeaturedCarouselItem(
                  title: title,
                  screenWidth: UIScreen.main.bounds.width,
                  onUpdateColor: { title in updateColor(for: title) },
                  onSelect: { title in
                    tappedSourceID = sourceID
                    selectedTitle = title
                  },
                  namespace: heroTransition,
                  sourceID: sourceID
                )
              }
            }
            .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
            .scrollTargetLayout()
          }
          .scrollTargetBehavior(.viewAligned)
          .frame(height: 460)
        }
      }

      // Grid with sticky sort header
      LazyVStack(pinnedViews: [.sectionHeaders]) {
        Section {
          // Grid of Posters
          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(titles) { title in
              let sourceID = "categoryGrid_\(title.id ?? 0)"
              PosterCard(
                title: title, width: nil, height: nil, namespace: heroTransition,
                sourceID: sourceID, showBorder: true
              )
              .aspectRatio(2 / 3, contentMode: .fit)
              .onTapGesture {
                tappedSourceID = sourceID
                selectedTitle = title
              }
            }
          }
          .padding(.horizontal)
        } header: {
          // Centered Sort Button (Sticky)
          HStack {
            Spacer()
            Menu {
              Picker("Sort By", selection: $selectedSort) {
                ForEach(SortOption.allCases) { option in
                  Label(option.rawValue, systemImage: option.icon).tag(option)
                }
              }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: selectedSort.icon)
                  .font(.system(size: 14, weight: .medium))
                Text(selectedSort.rawValue)
                  .font(.netflixSans(.medium, size: 14))
                Image(systemName: "chevron.down")
                  .font(.system(size: 10, weight: .semibold))
              }
              .foregroundStyle(.white)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background {
                if showTopBlur {
                  Capsule()
                    .fill(.clear)
                    .glassEffect(.regular, in: .capsule)
                } else {
                  Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                      Capsule()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
              }
            }
            Spacer()
          }
          .padding(.vertical, 10)
        }
      }
    }
    .padding(.vertical, 20)
  }

  @ViewBuilder
  private var defaultContent: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: 20) {
        ForEach(viewModel.featuredTitles.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty })
        { title in
          let sourceID = "featured_default_\(title.id ?? 0)"
          FeaturedCarouselItem(
            title: title,
            screenWidth: UIScreen.main.bounds.width,
            onUpdateColor: { title in
              updateColor(for: title)
            },
            onSelect: { title in
              tappedSourceID = sourceID
              selectedTitle = title
            },
            namespace: heroTransition,
            sourceID: sourceID
          )
        }
      }
      .padding(.horizontal, (UIScreen.main.bounds.width - 300) / 2)
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .frame(height: 460)

    // 1. In Theatres (Movies)
    if !viewModel.inTheatresMovies.isEmpty {
      SectionHeaderView(
        title: Constants.inTheatresString,
        subtitle: Constants.inTheatresSubtitleString,
        onTap: {
          titleDetailPath.append(
            SectionData(title: Constants.inTheatresString, items: viewModel.inTheatresMovies))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(
            viewModel.inTheatresMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
          ) { title in
            tappablePosterCard(title: title, section: "inTheatres")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    // 2. Popular Shows (TV) - MOVED UP
    if !viewModel.trendingTV.isEmpty {
      SectionHeaderView(
        title: "Popular Shows",
        subtitle: "Trending TV Series",
        onTap: {
          titleDetailPath.append(SectionData(title: "Popular Shows", items: viewModel.trendingTV))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(viewModel.trendingTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }) {
            title in
            tappablePosterCard(title: title, section: "default_trendingTV")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    // 3. Upcoming Movies
    if !viewModel.upcomingMovies.isEmpty {
      SectionHeaderView(
        title: "Upcoming Movies",
        subtitle: "Coming soon to theatres",
        onTap: {
          titleDetailPath.append(
            SectionData(title: "Upcoming Movies", items: viewModel.upcomingMovies))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(
            viewModel.upcomingMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
          ) { title in
            tappablePosterCard(title: title, section: "default_upcoming")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    // 4. Top Rated TV - MOVED UP
    if !viewModel.topRatedTV.isEmpty {
      SectionHeaderView(
        title: "Top Rated TV",
        subtitle: "All-time favorites",
        onTap: {
          titleDetailPath.append(SectionData(title: "Top Rated TV", items: viewModel.topRatedTV))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(viewModel.topRatedTV.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }) {
            title in
            tappablePosterCard(title: title, section: "default_topRatedTV")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    // 5. Popular Movies
    if !viewModel.popularMovies.isEmpty {
      SectionHeaderView(
        title: "Popular Movies",
        subtitle: "What everyone is watching",
        onTap: {
          titleDetailPath.append(
            SectionData(title: "Popular Movies", items: viewModel.popularMovies))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(
            viewModel.popularMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
          ) { title in
            tappablePosterCard(title: title, section: "default_popularMovies")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    // 6. Top Rated Movies
    if !viewModel.topRatedMovies.isEmpty {
      SectionHeaderView(
        title: "Top Rated Movies",
        subtitle: "Critically acclaimed",
        onTap: {
          titleDetailPath.append(
            SectionData(title: "Top Rated Movies", items: viewModel.topRatedMovies))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(
            viewModel.topRatedMovies.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
          ) { title in
            tappablePosterCard(title: title, section: "default_topRatedMovies")
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }

    SectionHeaderView(
      title: "Trending People",
      subtitle: "Popular Actors & Directors"
    )

    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 20) {
        ForEach(viewModel.trendingPeople) { person in
          NavigationLink(
            destination: PersonDetailView(
              personId: person.id, name: person.name, profileURL: person.profileURL)
          ) {
            VStack {
              AsyncImage(url: person.profileURL) { image in
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              } placeholder: {
                Color.gray.opacity(0.3)
              }
              .frame(width: 80, height: 120)
              .clipShape(Capsule())
              .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

              Text(person.name)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 80)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal)
    }
    .padding(.bottom, 100)
  }

  @ViewBuilder
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 15) {
      // Top row: Title and Search
      HStack {
        if !isSearchActive {
          Text(Constants.discoverString)
            .font(.netflixSans(.bold, size: 34))
            .foregroundStyle(.white)
            .matchedGeometryEffect(id: "Title", in: animation, anchor: .topLeading)
        }
        
        Spacer()
      }
      .padding(.horizontal)

      // Filter tabs row (only show when not searching)
      if !isSearchActive {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            if let filter = selectedFilter {
              // Close button
              Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.snappy) {
                  selectedFilter = nil
                  Task { await viewModel.getTitles() }
                }
              }) {
                Image(systemName: "xmark")
                  .font(.netflixSans(.medium, size: 15))
                  .padding(11)
                  .background(Color.clear)
                  .clipShape(Circle())
                  .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
                  )
              }
              .foregroundStyle(.white)
              .transition(.scale.combined(with: .opacity))

              // Context pill (Movies/Shows) if applicable
              if case .category(_, let context) = filter, let context = context {
                let isMovies = context == "movie"
                Text(isMovies ? Constants.moviesString : Constants.showsString)
                  .font(.netflixSans(.medium, size: 15))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
                  .background(Color.white.opacity(0.2))
                  .clipShape(Capsule())
                  .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6))
                  .foregroundStyle(.white)
                  .transition(.scale.combined(with: .opacity))
                  .matchedGeometryEffect(id: isMovies ? "Movies" : "Shows", in: animation)
                  .onTapGesture {
                    withAnimation(.snappy) {
                      selectedFilter = isMovies ? .movies : .shows
                      Task { await viewModel.getTitles() }
                    }
                  }
              } else if filter == .movies || filter == .shows {
                Text(filter.displayTitle)
                  .font(.netflixSans(.medium, size: 15))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
                  .background(Color.white.opacity(0.2))
                  .clipShape(Capsule())
                  .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6))
                  .foregroundStyle(.white)
                  .transition(.scale.combined(with: .opacity))
                  .matchedGeometryEffect(id: filter.geometryId, in: animation)
              }
            } else {
              // Default: Shows button
              Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.snappy) {
                  selectedFilter = .shows
                  Task { await viewModel.getTitles() }
                }
              }) {
                Text(Constants.showsString)
                  .font(.netflixSans(.medium, size: 15))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
                  .background(Color.clear)
                  .clipShape(Capsule())
                  .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6))
              }
              .foregroundStyle(.white)
              .matchedGeometryEffect(id: "Shows", in: animation)

              // Default: Movies button
              Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.snappy) {
                  selectedFilter = .movies
                  Task { await viewModel.getTitles() }
                }
              }) {
                Text(Constants.moviesString)
                  .font(.netflixSans(.medium, size: 15))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
                  .background(Color.clear)
                  .clipShape(Capsule())
                  .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6))
              }
              .foregroundStyle(.white)
              .matchedGeometryEffect(id: "Movies", in: animation)
            }

            // Categories Menu - ALWAYS PRESENT, never duplicated
            categoriesMenuButton(geometryId: "CategoryPill")
          }
          .padding(.horizontal)
          .animation(.snappy, value: selectedFilter)
        }
      }
    }
    .padding(.top, 60)
    .padding(.bottom, 15)
    .background(
      Color.clear
        .glassEffect(
          .regular,
          in: UnevenRoundedRectangle(
            topLeadingRadius: UIScreen.screenCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: UIScreen.screenCornerRadius,
            style: .continuous
          )
        )
        .ignoresSafeArea(edges: .top)
        .opacity(showTopBlur || isSearchActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showTopBlur)
        .animation(.easeInOut(duration: 0.2), value: isSearchActive)
    )
  }

  @ViewBuilder
  private func activeFilterView(filter: HomeFilter) -> some View {
    // Close Button (Always clears everything)
    Button(action: {
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.impactOccurred()
      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
        selectedFilter = nil
        // Refresh default content
        Task { await viewModel.getTitles() }
      }
    }) {
      Image(systemName: "xmark")
        .font(.netflixSans(.medium, size: 15))
        .padding(6)
        .background(Color.clear)
        .clipShape(Circle())
        .overlay(
          Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
    }
    .foregroundStyle(.white)
    .transition(
      .asymmetric(
        insertion: .scale(scale: 0.8).combined(with: .opacity),
        removal: .scale(scale: 0.8).combined(with: .opacity)
      ))

    // Logic for separating Media Type and Genre Pills

    // 1. Context Pill (Movies or Shows) - if applicable
    if case .category(_, let context) = filter, let context = context {
      let isMovies = context == "movie"
      let title = isMovies ? Constants.moviesString : Constants.showsString
      let geoId = isMovies ? HomeFilter.movies.geometryId : HomeFilter.shows.geometryId

      Text(title)
        .font(.netflixSans(.medium, size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
        .foregroundStyle(.white)
        .matchedGeometryEffect(id: geoId, in: animation)
        .onTapGesture {
          // Optional: Tapping the context pill could clear the genre but keep the context?
          // For now, let's keep it simple: It's just a display state.
          // Taking user request literally: "showup sepearte".
          // If we want it interactive (go back to just Movies), we could do:
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedFilter = isMovies ? .movies : .shows
            Task { await viewModel.getTitles() }  // Fetch default movies/shows
            // Wait, getTitles grabs trending. We might want just "Movies" filter logic?
            // Actually, switching to .movies triggers the view to show movie sections,
            // but we might need to refresh data if getTitles was filtered.
            // Re-fetching titles is safest to clear genre filter.
          }
        }
    } else if filter == .movies || filter == .shows {
      // Standard single media filter
      Text(filter.displayTitle)
        .font(.netflixSans(.medium, size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
        .foregroundStyle(.white)
        .matchedGeometryEffect(id: filter.geometryId, in: animation)
    }

    // 2. Genre Pill - only if it's a category filter
    if case .category(let genre, _) = filter {
      Text(genre.name)
        .font(.netflixSans(.medium, size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
        .foregroundStyle(.white)
        .transition(
          .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
          ))
    }

    // All Categories Menu
    categoriesMenuButton(geometryId: "CategoryPill")
  }

  @ViewBuilder
  private var defaultFilterOptions: some View {
    // Shows
    Button(action: {
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.impactOccurred()
      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
        selectedFilter = .shows
        Task { await viewModel.getTitles() }
      }
    }) {
      Text(Constants.showsString)
        .font(.netflixSans(.medium, size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
    }
    .foregroundStyle(.white)
    .matchedGeometryEffect(id: HomeFilter.shows.geometryId, in: animation)

    // Movies
    Button(action: {
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.impactOccurred()
      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
        selectedFilter = .movies
        Task { await viewModel.getTitles() }
      }
    }) {
      Text(Constants.moviesString)
        .font(.netflixSans(.medium, size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
        )
    }
    .foregroundStyle(.white)
    .matchedGeometryEffect(id: HomeFilter.movies.geometryId, in: animation)

    // Categories
    categoriesMenuButton(geometryId: "CategoryPill")
  }

  @ViewBuilder
  private func categoriesMenuButton(geometryId: String?) -> some View {
    // Determine current genre name if a category is selected
    let currentGenreName: String? = {
      if case .category(let genre, _) = selectedFilter {
        return genre.name
      }
      return nil
    }()

    Button(action: {
      withAnimation(.snappy) { showCategoryMenu = true }
    }) {
      HStack(spacing: 4) {
        Text(currentGenreName ?? "Categories")
        Image(systemName: "chevron.down")
          .font(.caption)
      }
      .font(.netflixSans(.medium, size: 15))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(currentGenreName != nil ? Color.white.opacity(0.2) : Color.clear)
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
      )
    }
    .foregroundStyle(.white)
  }

  // Helper View for reusable Poster Card
  @ViewBuilder
  private func tappablePosterCard(title: Title, section: String = "default") -> some View {
    let uniqueSourceID = "\(section)_\(title.id ?? 0)"
    PosterCard(title: title, namespace: heroTransition, sourceID: uniqueSourceID)
      .id(uniqueSourceID) // Ensure stable identity for transition
      .onTapGesture {
        guard let id = title.id else { return }
        let mediaType = title.name != nil ? "tv" : "movie"

        // Start prefetching data immediately
        TMDBClient.shared.prefetchTitle(id: id, mediaType: mediaType)

        // Store source ID for hero transition
        tappedSourceID = uniqueSourceID

        // Delay navigation slightly to let prefetch start loading
        // User feedback: "takes a while". Removing delay.
        // The 0.6s zoom transition will cover some loading time.
        selectedTitle = title
      }
  }

  private func updateColor(for title: Title) {
    guard let id = title.id else { return }

    // 1. Check Cache
    if let cachedColor = colorCache[id] {
      if currentPosterColor != cachedColor {
        withAnimation(.easeInOut(duration: 0.5)) {
          currentPosterColor = cachedColor
        }
      }
      return
    }

    guard let posterPath = title.posterPath else { return }
    let url: URL?
    if posterPath.hasPrefix("http") {
      url = URL(string: posterPath)
    } else {
      let cleanPath = posterPath.hasPrefix("/") ? posterPath : "/\(posterPath)"
      url = URL(string: "https://image.tmdb.org/t/p/w200\(cleanPath)")
    }
    guard let url else { return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, let uiImage = UIImage(data: data) else { return }
      if let avgColor = uiImage.dominantBrightColor {
        let newColor = Color(uiColor: avgColor)
        DispatchQueue.main.async {
          // Save to cache
          self.colorCache[id] = newColor

          withAnimation(.easeInOut(duration: 0.5)) {
            self.currentPosterColor = newColor
          }
        }
      }
    }.resume()
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    HomeView(isSearchActive: .constant(false))
  } else {
    Text("Requires iOS 26.0+")
  }
}

// Helper for Navigation
struct SectionData: Hashable {
  let title: String
  let items: [Title]
}
