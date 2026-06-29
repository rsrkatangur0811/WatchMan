import SwiftData
import SwiftUI

struct HomeView: View {

  @State private var viewModel = ViewModel()
  @State private var titleDetailPath = NavigationPath()
  @Environment(\.modelContext) var modelContext
  @Query(sort: \UserLibraryItem.modifiedAt, order: .reverse) private var libraryItems: [UserLibraryItem]
  @State private var currentGradientColors: [Color] = [.black.opacity(0.6), .black]
  @State private var webImageLoader = ImageLoader()
  @State private var showTopBlur = false
  @State private var selectedFilter: HomeFilter? = nil
  @Namespace private var animation
  @Namespace private var heroTransition
  
  // Bundled state for zoom transition
  struct TransitionSelection: Hashable {
    let title: Title
    let sourceID: String

    init(title: Title, sourceID: String) {
      self.title = title
      self.sourceID = sourceID
    }
  }
  @State private var transitionSelection: TransitionSelection? = nil

  @State private var colorCache: [Int: [Color]] = [:]
  @State private var selectedSort: SortOption = .defaults
  @State private var showCategoryMenu: Bool = false
  @State private var lastScrollOffset: CGFloat = 0
  @State private var isScrollingDown: Bool = false
  @State private var personalizedDiscoveryTask: Task<Void, Never>?
  @State private var featuredCarouselSelections: [String: String] = [:]
  @State private var featuredCarouselDragOffsets: [String: CGFloat] = [:]
  @State private var featuredCarouselTimerResets: [String: Int] = [:]
  
  // Search state
  @Binding var isSearchActive: Bool
  @State private var searchText: String = ""
  @State private var isSearching: Bool = false // Add loading state
  @State private var showSearchTopBlur: Bool = false // Scroll state for search header
  @State private var searchViewModel = SearchViewModel()
  @FocusState private var isSearchFieldFocused: Bool
  @State private var containerWidth: CGFloat = UIScreen.main.bounds.width

  init(isSearchActive: Binding<Bool>) {
    self._isSearchActive = isSearchActive
  }

  enum HomeFilter: Identifiable, Equatable, Hashable {
    case shows
    case movies
    case country
    case category(Genre, String? = nil)

    var id: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .country: return "Country"
      case .category(let genre, let context): return "category-\(genre.id)-\(context ?? "all")"
      }
    }

    // Helper to get raw string for display
    var displayTitle: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .country: return ViewModel.deviceCountryName
      case .category(let genre, _): return genre.name
      }
    }

    // Geometry ID for smooth transitions
    var geometryId: String {
      switch self {
      case .shows: return "Shows"
      case .movies: return "Movies"
      case .country: return "Country"
      case .category: return "CategoryPill"
      }
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: ContainerWidthKey.self, value: proxy.size.width)
          }
        )
        .onPreferenceChange(ContainerWidthKey.self) { width in
          containerWidth = width
        }

      // Dynamic Background Gradient
      ZStack {
        LinearGradient(
          colors: currentGradientColors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: currentGradientColors)
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
                         ForEach(titles, id: \.stableDisplayID) { title in
                             let width = (containerWidth - 56) / 3
                             let height = width * 1.5
                             let sourceID = "categoryGrid_\(title.stableDisplayID)"
                             
                             PosterCard(
                               title: title, width: width, height: height, namespace: heroTransition,
                               sourceID: sourceID, showBorder: true
                             )
                             .id(title.id) // Use stable ID, removed posterPath check to prevent recreation
                             .aspectRatio(2 / 3, contentMode: .fit)
                             .onTapGesture {
                               transitionSelection = TransitionSelection(
                                 title: title,
                                 sourceID: sourceID
                               )
                             }
                              .onAppear {
                                if let titleId = title.id, let lastId = titles.last?.id, titleId == lastId {
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
      .compatibleOnScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showTopBlur = newValue > 20
        }
        // Hide-on-scroll detection
        let threshold: CGFloat = 10
        if newValue > lastScrollOffset + threshold {
          // Scrolling down
          withAnimation(.easeOut(duration: 0.25)) {
            isScrollingDown = true
          }
        } else if newValue < lastScrollOffset - threshold {
          // Scrolling up
          withAnimation(.easeOut(duration: 0.25)) {
            isScrollingDown = false
          }
        }
        lastScrollOffset = newValue
      }
      .overlay {
        if showCategoryMenu {
          FullScreenCategoryMenu(
            isPresented: $showCategoryMenu,
            selectedFilter: $selectedFilter,
            genres: availableGenres,
            countryName: ViewModel.deviceCountryName,
            onSelectCountry: {
              withAnimation(.snappy) {
                selectedFilter = .country
                Task { await viewModel.loadCountrySectionsIfNeeded() }
              }
            },
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
      .navigationDestination(item: $transitionSelection) { selection in
        TitleDetailView(
          title: selection.title,
          zoomNamespace: heroTransition,
          zoomSourceID: selection.sourceID
        )
      }
      .toolbar(showCategoryMenu || isSearchActive ? .hidden : .visible, for: .tabBar)
      // Hide the CUSTOM Liquid Glass Tab Bar when searching
      .preference(key: TabBarVisibilityPreferenceKey.self, value: isSearchActive || showCategoryMenu || isScrollingDown)
      .navigationDestination(for: SectionData.self) { section in
        SectionResultsView(title: section.title, items: section.items)
      }
    }
    .task {
      // Only fetch if not already loaded (to avoid reset on back from detail)
      if viewModel.homeStatus == .notStarted {
        await viewModel.getTitles()
      }
      await viewModel.loadPersonalizedDiscoveryIfNeeded(from: libraryItems)
      await viewModel.loadCountrySectionsIfNeeded()
      await viewModel.loadCustomCategoriesIfNeeded()
    }
    .onChange(of: libraryItems.map { "\($0.uniqueId)_\($0.modifiedAt.timeIntervalSince1970)" }) { _, _ in
      personalizedDiscoveryTask?.cancel()
      personalizedDiscoveryTask = Task {
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard !Task.isCancelled else { return }
        await viewModel.refreshPersonalizedDiscovery(from: libraryItems)
      }
    }
  }

	  // MARK: - Subviews
	  
	  private func posterBackedTitles(_ titles: [Title]) -> [Title] {
	    titles.filter { title in
	      guard let posterPath = title.posterPath else { return false }
	      return !posterPath.isEmpty
	    }
	  }

  private func featuredSelectionID(section: String, title: Title) -> String {
    "\(section)_\(title.stableDisplayID)"
  }

  private func featuredLeadingSentinelID(section: String) -> String {
    "\(section)_leading_wrap"
  }

  private func featuredTrailingSentinelID(section: String) -> String {
    "\(section)_trailing_wrap"
  }

  private func selectedFeaturedIndex(section: String, titles: [Title]) -> Int {
    guard let selectedID = featuredCarouselSelections[section],
      let index = titles.firstIndex(where: { featuredSelectionID(section: section, title: $0) == selectedID })
    else {
      return 0
    }
    return index
  }

  private func updateFeaturedCarouselSelection(
    _ newValue: String?,
    section: String,
    titles: [Title]
  ) {
    guard let newValue else { return }

    if newValue == featuredLeadingSentinelID(section: section), let last = titles.last {
      jumpFeaturedCarousel(
        section: section,
        to: featuredSelectionID(section: section, title: last),
        delay: 0.16
      )
      return
    }

    if newValue == featuredTrailingSentinelID(section: section), let first = titles.first {
      jumpFeaturedCarousel(
        section: section,
        to: featuredSelectionID(section: section, title: first),
        delay: 0.16
      )
      return
    }

    featuredCarouselSelections[section] = newValue
    updateFeaturedCarouselBackground(section: section, titles: titles)
  }

  private func jumpFeaturedCarousel(section: String, to id: String, delay: TimeInterval = 0) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        featuredCarouselSelections[section] = id
      }
    }
  }

  private func nextFeaturedCarouselSelection(
    section: String,
    titles: [Title]
  ) -> (id: String, title: Title)? {
    guard titles.count > 1 else { return nil }
    let currentIndex = selectedFeaturedIndex(section: section, titles: titles)
    let nextIndex = (currentIndex + 1) % titles.count
    let nextTitle = titles[nextIndex]
    return (featuredSelectionID(section: section, title: nextTitle), nextTitle)
  }

  private func updateFeaturedCarouselBackground(section: String, titles: [Title]) {
    let selectedIndex = selectedFeaturedIndex(section: section, titles: titles)
    guard titles.indices.contains(selectedIndex) else { return }
    updateColor(for: titles[selectedIndex])
  }

	  @ViewBuilder
	  private func featuredCarousel(
	    titles: [Title],
		    section: String,
		    limit: Int? = nil
			  ) -> some View {
		    let requestedLimit = min(limit ?? 20, 20)
		    let rowTitles = Array(posterBackedTitles(titles).prefix(requestedLimit))

	    if !rowTitles.isEmpty {
	      VStack(spacing: 8) {
          let selectedIndex = selectedFeaturedIndex(section: section, titles: rowTitles)
          let cardWidth: CGFloat = 300
          let cardSpacing: CGFloat = 20
          let pageWidth = cardWidth + cardSpacing
          let dragOffset = featuredCarouselDragOffsets[section] ?? 0
          let carouselTimerID = [
            rowTitles.map(\.stableDisplayID).joined(separator: "|"),
            featuredCarouselSelections[section] ?? "",
            "\(featuredCarouselTimerResets[section] ?? 0)"
          ].joined(separator: "::")

          ZStack(alignment: .leading) {
            HStack(alignment: .top, spacing: cardSpacing) {
              ForEach(Array(rowTitles.enumerated()), id: \.element.stableDisplayID) { index, title in
                let sourceID = featuredSelectionID(section: section, title: title)
                let rawDistance = CGFloat(index - selectedIndex) - (dragOffset / pageWidth)
                let distance = min(abs(rawDistance), 1)

                FeaturedCarouselItem(
                  title: title,
                  screenWidth: containerWidth,
                  onUpdateColor: { _ in },
                  onSelect: { title in
                    transitionSelection = TransitionSelection(
                      title: title,
                      sourceID: sourceID
                    )
                  },
                  namespace: heroTransition,
                  sourceID: sourceID
                )
                .scaleEffect(1 - (0.08 * distance))
                .blur(radius: 10 * distance)
                .opacity(1 - (0.4 * distance))
                .rotation3DEffect(
                  .degrees(rawDistance * 15),
                  axis: (x: 0, y: 1, z: 0),
                  perspective: 0.5
                )
                .id(sourceID)
              }
            }
            .offset(
              x: ((containerWidth - cardWidth) / 2)
                - (CGFloat(selectedIndex) * pageWidth)
                + dragOffset
            )
          }
          .frame(width: containerWidth, height: 450, alignment: .leading)
          .clipped()
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 10)
              .onChanged { value in
                featuredCarouselDragOffsets[section] = value.translation.width
              }
	              .onEnded { value in
	                let predictedOffset = value.predictedEndTranslation.width
	                let threshold = pageWidth * 0.25
	                var nextIndex = selectedIndex

	                if predictedOffset < -threshold {
	                  nextIndex = min(selectedIndex + 1, rowTitles.count - 1)
	                } else if predictedOffset > threshold {
	                  nextIndex = max(selectedIndex - 1, 0)
	                }

	                withAnimation(.snappy(duration: 0.45)) {
	                  featuredCarouselDragOffsets[section] = 0
	                  featuredCarouselSelections[section] = featuredSelectionID(
	                    section: section,
	                    title: rowTitles[nextIndex]
	                  )
	                }
	                featuredCarouselTimerResets[section, default: 0] += 1
	                updateColor(for: rowTitles[nextIndex])
	              }
	          )
          .onAppear {
            if featuredCarouselSelections[section] == nil, let first = rowTitles.first {
              featuredCarouselSelections[section] = featuredSelectionID(section: section, title: first)
            }
            updateFeaturedCarouselBackground(section: section, titles: rowTitles)
          }
          .task(id: carouselTimerID) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            guard let nextSelection = nextFeaturedCarouselSelection(section: section, titles: rowTitles) else {
              return
            }
            withAnimation(.snappy(duration: 0.55)) {
              featuredCarouselDragOffsets[section] = 0
              featuredCarouselSelections[section] = nextSelection.id
            }
            updateColor(for: nextSelection.title)
          }

	      }
	      .frame(height: 458)
	    }
	  }

  @ViewBuilder
  private func horizontalTitleSection(
    title: String,
    subtitle: String,
    items: [Title],
    section: String
  ) -> some View {
    if !items.isEmpty {
      let rowTitles = posterBackedTitles(items)

      SectionHeaderView(
        title: title,
        subtitle: subtitle,
        onTap: {
          titleDetailPath.append(SectionData(title: title, items: items))
        }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 15) {
          ForEach(rowTitles, id: \.stableDisplayID) { title in
            tappablePosterCard(title: title, section: section)
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 220)
      .padding(.bottom, 20)
    }
  }

  @ViewBuilder
  private func sectionsContent(for filter: HomeFilter) -> some View {
    VStack(spacing: 10) {
      if filter == .country {
        countryContent
      }

      if shouldShowMovies(for: filter) {
        featuredCarousel(titles: viewModel.inTheatresMovies, section: "featured_movies")
        horizontalTitleSection(
          title: "Popular Movies",
          subtitle: "What everyone's watching",
          items: viewModel.popularMovies,
          section: "popularMovies"
        )
        horizontalTitleSection(
          title: "New & Upcoming",
          subtitle: "Fresh arrivals",
          items: viewModel.upcomingMovies,
          section: "upcomingMovies"
        )
        horizontalTitleSection(
          title: "Top Rated Movies",
          subtitle: "Critically acclaimed",
          items: viewModel.topRatedMovies,
          section: "topRatedMovies"
        )

        // Dynamic Movie Sections
        ForEach(viewModel.movieSections) { section in
          horizontalTitleSection(
            title: section.title,
            subtitle: section.subtitle,
            items: section.items,
            section: "movieSection_\(section.title)"
          )
        }
      }

      if shouldShowShows(for: filter) {
        // Hero Carousel for TV Shows (Trending)
        featuredCarousel(titles: viewModel.trendingTV, section: "featured_tv", limit: 10)

        // 1. Trending TV (if not fully covered by Hero, or show remaining)
        // Actually, let's show "Popular Shows" first
        horizontalTitleSection(
          title: "Popular Shows",
          subtitle: "Most watched series",
          items: viewModel.popularTV,
          section: "popularTV"
        )

        // 2. Airing Today
        horizontalTitleSection(
          title: "Airing Today",
          subtitle: "New episodes available now",
          items: viewModel.airingTodayTV,
          section: "airingTodayTV"
        )

        // 3. On The Air
        horizontalTitleSection(
          title: "On The Air",
          subtitle: "Currently airing seasons",
          items: viewModel.onTheAirTV,
          section: "onTheAirTV"
        )

        // 4. Top Rated TV
        horizontalTitleSection(
          title: "Top Rated TV",
          subtitle: "All-time favorites",
          items: viewModel.topRatedTV,
          section: "topRatedTV"
        )

        // 5. Custom Categories (Dynamic)
        ForEach(viewModel.tvSections) { section in
          horizontalTitleSection(
            title: section.title,
            subtitle: section.subtitle,
            items: section.items,
            section: "tvSection_\(section.title)"
          )
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
    case .country: return false
    case .category(_, let type): return type == nil || type == "movie"
    }
  }

  private func shouldShowShows(for filter: HomeFilter) -> Bool {
    switch filter {
    case .shows: return true
    case .movies: return false
    case .country: return false
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
        featuredCarousel(titles: viewModel.inTheatresMovies, section: "category_movie")
      } else {
        featuredCarousel(titles: viewModel.trendingTV, section: "category_tv", limit: 10)
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
        Image(systemName: selectedSort.icon)
          .font(.system(size: 15, weight: .semibold))
          .iconPillControl(minWidth: 58, height: 42)
          .accessibilityLabel("Sort By")
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

  @ViewBuilder
  private var defaultContent: some View {
    featuredCarousel(titles: viewModel.featuredTitles, section: "featured_default")

    personalizedDiscoveryContent

    countryRowsContent

    horizontalTitleSection(
      title: Constants.inTheatresString,
      subtitle: Constants.inTheatresSubtitleString,
      items: viewModel.inTheatresMovies,
      section: "inTheatres"
    )
    horizontalTitleSection(
      title: "Popular Shows",
      subtitle: "Trending TV Series",
      items: viewModel.trendingTV,
      section: "default_trendingTV"
    )
    horizontalTitleSection(
      title: "Upcoming Movies",
      subtitle: "Coming soon to theatres",
      items: viewModel.upcomingMovies,
      section: "default_upcoming"
    )
    horizontalTitleSection(
      title: "Top Rated TV",
      subtitle: "All-time favorites",
      items: viewModel.topRatedTV,
      section: "default_topRatedTV"
    )
    horizontalTitleSection(
      title: "Popular Movies",
      subtitle: "What everyone is watching",
      items: viewModel.popularMovies,
      section: "default_popularMovies"
    )
    horizontalTitleSection(
      title: "Top Rated Movies",
      subtitle: "Critically acclaimed",
      items: viewModel.topRatedMovies,
      section: "default_topRatedMovies"
    )

    SectionHeaderView(
      title: "Trending People",
      subtitle: "Popular Actors & Directors"
    )

    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: 20) {
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
                .lineLimit(2)
                .multilineTextAlignment(.center)
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
  private var countryRowsContent: some View {
    ForEach(viewModel.countryMovieSections) { section in
      horizontalTitleSection(
        title: section.title,
        subtitle: section.subtitle,
        items: section.items,
        section: "countryMovie_\(section.title)"
      )
    }

    ForEach(viewModel.countryTVSections) { section in
      horizontalTitleSection(
        title: section.title,
        subtitle: section.subtitle,
        items: section.items,
        section: "countryTV_\(section.title)"
      )
    }
  }

  @ViewBuilder
  private var countryContent: some View {
    featuredCarousel(titles: viewModel.countryFeaturedTitles, section: "featured_country")
    countryRowsContent
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
                  .iconPillControl(minWidth: 50, height: 38)
              }
              .foregroundStyle(.white)
              .transition(.scale.combined(with: .opacity))

              // Context pill (Movies/Shows) if applicable
              if case .category(_, let context) = filter, let context = context {
                let isMovies = context == "movie"
                filterPillLabel(isMovies ? Constants.moviesString : Constants.showsString, isSelected: true)
                  .transition(.scale.combined(with: .opacity))
                  .matchedGeometryEffect(id: isMovies ? "Movies" : "Shows", in: animation)
                  .onTapGesture {
                    withAnimation(.snappy) {
                      selectedFilter = isMovies ? .movies : .shows
                      Task { await viewModel.getTitles() }
                    }
                  }
              } else if filter == .movies || filter == .shows {
                filterPillLabel(filter.displayTitle, isSelected: true)
                  .transition(.scale.combined(with: .opacity))
                  .matchedGeometryEffect(id: filter.geometryId, in: animation)
              } else if filter == .country {
                filterPillLabel(filter.displayTitle, isSelected: true)
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
                filterPillLabel(Constants.showsString)
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
                filterPillLabel(Constants.moviesString)
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
        .glassedEffect(
          in: UnevenRoundedRectangle(
            topLeadingRadius: UIScreen.screenCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: UIScreen.screenCornerRadius,
            style: .continuous
	          ),
		          isEnabled: showTopBlur || isSearchActive
	        )
        .ignoresSafeArea(edges: .top)
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
        .iconPillControl(minWidth: 50, height: 38)
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

      filterPillLabel(title, isSelected: true)
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
      filterPillLabel(filter.displayTitle, isSelected: true)
        .matchedGeometryEffect(id: filter.geometryId, in: animation)
    } else if filter == .country {
      filterPillLabel(filter.displayTitle, isSelected: true)
        .matchedGeometryEffect(id: filter.geometryId, in: animation)
    }

    // 2. Genre Pill - only if it's a category filter
    if case .category(let genre, _) = filter {
      filterPillLabel(genre.name, isSelected: true)
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
      filterPillLabel(Constants.showsString)
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
      filterPillLabel(Constants.moviesString)
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
      filterPillLabel(
        currentGenreName ?? "Categories",
        systemImage: "chevron.down",
        isSelected: currentGenreName != nil
      )
    }
    .foregroundStyle(.white)
  }

  private func filterPillLabel(
    _ title: String,
    systemImage: String? = nil,
    isSelected: Bool = false
  ) -> some View {
    HStack(spacing: 6) {
      Text(title)
        .lineLimit(1)
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .semibold))
      }
    }
    .font(.netflixSans(.medium, size: 15))
    .foregroundStyle(.white)
	    .padding(.horizontal, 16)
	    .padding(.vertical, 9)
	    .background {
	      Capsule()
	        .fill(.clear)
	        .glassedEffect(in: Capsule())
	    }
	    .overlay {
	      ZStack {
	        Capsule()
	          .fill(Color.white.opacity(isSelected ? 0.14 : 0.04))
	        Capsule()
	          .strokeBorder(Color.white.opacity(isSelected ? 0.42 : 0.26), lineWidth: 0.8)
	      }
	    }
    .clipShape(Capsule())
    .contentShape(Capsule())
  }

  @ViewBuilder
  private var personalizedDiscoveryContent: some View {
    ForEach(viewModel.personalizedSections) { section in
      horizontalTitleSection(
        title: section.title,
        subtitle: section.subtitle,
        items: section.items,
        section: "personalized_\(section.title)"
      )
    }
  }

  // Helper View for reusable Poster Card
  @ViewBuilder
  private func tappablePosterCard(
    title: Title,
    section: String = "default"
  ) -> some View {
    let uniqueSourceID = "\(section)_\(title.stableDisplayID)"
    PosterCard(
      title: title,
      namespace: heroTransition,
      sourceID: uniqueSourceID,
      showBorder: true
    )
      .id(uniqueSourceID) // Ensure stable identity for transition
      .onTapGesture {
        guard let id = title.id else { return }
        let mediaType = title.name != nil ? "tv" : "movie"

        // Start prefetching data immediately
        TMDBClient.shared.prefetchTitle(id: id, mediaType: mediaType)

        // Store source ID for hero transition and navigate
        transitionSelection = TransitionSelection(
          title: title,
          sourceID: uniqueSourceID
        )
      }
  }

  private func updateColor(for title: Title) {
    guard let id = title.id else { return }

    // 1. Check Cache
    if let cachedColors = colorCache[id] {
      if currentGradientColors != cachedColors {
        withAnimation(.easeInOut(duration: 0.8)) {
          currentGradientColors = cachedColors
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

    Task {
      guard let uiImage = try? await ImageLoader.cachedImage(for: url) else { return }

      // Extract multiple vibrant colors
      if let uiColors = uiImage.extractVibrantColors(count: 4) {
        let swiftUIColors = uiColors.map { Color(uiColor: $0).opacity(0.6) }
        // Pad to 4 colors, add black at end for fade effect
        let paddedColors = self.padColors(swiftUIColors, to: 3) + [.black]

        // Save to cache
        self.colorCache[id] = paddedColors

        withAnimation(.easeInOut(duration: 0.8)) {
          self.currentGradientColors = paddedColors
        }
      } else if let avgColor = uiImage.dominantBrightColor {
        // Fallback to single color
        let newColor = Color(uiColor: avgColor).opacity(0.6)
        let fallbackColors = [newColor, newColor.opacity(0.3), .black]

        self.colorCache[id] = fallbackColors
        withAnimation(.easeInOut(duration: 0.8)) {
          self.currentGradientColors = fallbackColors
        }
      }
    }
  }

  /// Pads color array to desired count by repeating the last color
  private func padColors(_ colors: [Color], to count: Int) -> [Color] {
    guard !colors.isEmpty else { return Array(repeating: .clear, count: count) }
    if colors.count >= count { return Array(colors.prefix(count)) }
    return colors + Array(repeating: colors.last!, count: count - colors.count)
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

// Captures the actual container width for adaptive layouts (iPad, Split View, etc.)
private struct ContainerWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = UIScreen.main.bounds.width
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
