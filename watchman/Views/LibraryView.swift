import SwiftData
import SwiftUI

@available(iOS 26.0, *)
struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var selectedTab: LibraryTab = .watchlist
  @State private var selectedMediaType: String? = nil
  @Query(sort: \UserLibraryItem.modifiedAt, order: .reverse) private var allItems: [UserLibraryItem]
  @State private var showTopBlur = false
  @Namespace private var heroTransition

  enum LibraryTab: String, CaseIterable {
    case watchNext = "Watch Next"
    case watchlist = "Watchlist"
    case watched = "Watched"

    var icon: String {
      switch self {
      case .watchNext: return "play.circle"
      case .watchlist: return "bookmark"
      case .watched: return "checkmark.circle"
      }
    }

    var emptyIcon: String {
      switch self {
      case .watchNext: return "play.slash"
      case .watchlist: return "bookmark.slash"
      case .watched: return "eye.slash"
      }
    }

    var emptyMessage: String {
      switch self {
      case .watchNext: return "No shows to continue"
      case .watchlist: return "No titles in your watchlist"
      case .watched: return "No watched titles yet"
      }
    }

    var emptySubtitle: String {
      switch self {
      case .watchNext: return "Start watching a TV show to see it here"
      case .watchlist: return "Tap the bookmark icon on any title to add it here"
      case .watched: return "Mark titles as watched to track your viewing history"
      }
    }
  }

  private var filteredItems: [UserLibraryItem] {
    let typeFiltered: [UserLibraryItem]
    if let type = selectedMediaType {
      typeFiltered = allItems.filter { $0.mediaType == type }
    } else {
      typeFiltered = allItems
    }

    switch selectedTab {
    case .watchNext:
      // TV shows with at least one watched episode but not fully watched
      return typeFiltered.filter { item in
        guard item.mediaType == "tv" else { return false }
        let progress = UserLibraryManager.shared.getShowProgress(showId: item.titleId)
        return progress > 0 && !item.isWatched
      }
    case .watchlist:
      return typeFiltered.filter { $0.isWatchlist }
    case .watched:
      return typeFiltered.filter { $0.isWatched }
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      ScrollView {
        LazyVStack(pinnedViews: [.sectionHeaders]) {
          Section {
            if filteredItems.isEmpty {
              emptyState
                .frame(minHeight: 400)
            } else if selectedTab == .watchNext {
              watchNextList
            } else {
              contentGrid
            }
          } header: {
            VStack(spacing: 0) {
              // 1. Home-Style Header (Title + Type Filters)
              headerView

              // 2. Separate Floating Tabs (Watchlist, Watched, Rated)
              tabSelector
                .padding(.horizontal)
                .padding(.top, 10)
            }
          }
        }
      }
      .ignoresSafeArea(edges: .top)  // Needed for custom header to reach top
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showTopBlur = newValue > 20
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)  // Hide standard nav bar
    .onChange(of: selectedMediaType) { _, newValue in
      // If Movies filter is selected and Watch Next is active, switch to Watchlist
      if newValue == "movie" && selectedTab == .watchNext {
        selectedTab = .watchlist
      }
    }
  }

  // MARK: - Header
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Library")
        .font(.netflixSans(.bold, size: 34))
        .foregroundStyle(.white)
        .padding(.horizontal)

      // Type Filters (Movies / Shows) like HomeView
      HStack(spacing: 8) {
        if let selected = selectedMediaType {
          // Active State: Show Close Button + Selected Pill

          // Close Button
          Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.snappy) {
              selectedMediaType = nil
            }
          } label: {
            Image(systemName: "xmark")
              .font(.netflixSans(.medium, size: 15))
              .padding(6)
              .background(Color.clear)
              .clipShape(Circle())
              .overlay(
                Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
              )
          }
          .foregroundStyle(.white)
          .transition(.scale.combined(with: .opacity))

          // Selected Pill
          Text(selected == "movie" ? "Movies" : "Shows")
            .font(.netflixSans(.medium, size: 15))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            .overlay(
              Capsule()
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .transition(.scale.combined(with: .opacity))
            .matchedGeometryEffect(id: selected, in: heroTransition)

        } else {
          // Default State: Show Options

          // Movies Button
          Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.snappy) { selectedMediaType = "movie" }
          } label: {
            Text("Movies")
              .font(.netflixSans(.medium, size: 15))
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Color.clear)
              .clipShape(Capsule())
              .overlay(
                Capsule()
                  .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
              )
          }
          .foregroundStyle(.white)
          .buttonStyle(.plain)
          .matchedGeometryEffect(id: "movie", in: heroTransition)

          // Shows Button
          Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.snappy) { selectedMediaType = "tv" }
          } label: {
            Text("Shows")
              .font(.netflixSans(.medium, size: 15))
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Color.clear)
              .clipShape(Capsule())
              .overlay(
                Capsule()
                  .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
              )
          }
          .foregroundStyle(.white)
          .buttonStyle(.plain)
          .matchedGeometryEffect(id: "tv", in: heroTransition)
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 15)
    }
    .padding(.top, 60)  // Safe area compensation
    .frame(maxWidth: .infinity, alignment: .leading)
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
        // HomeView uses rounded top... but since we are at top, 0 is fine or 62?
        // HomeView: topLeadingRadius: 62.
        // Let's match HomeView exactly just in case.
        // But wait, HomeView header shape is specific.
        // I will use 0 radius for a standard full header look, or copy HomeView's shape?
        // "Implement the same header style". I will copy the shape.
        // But HomeView's shape might be for a specific design (tab bar cutout?).
        // Let's use 0 for now as it's cleaner for Library, unless explicit.
        // Actually, if I use 0, it covers the top fully.
        .ignoresSafeArea(edges: .top)
        .opacity(showTopBlur ? 1 : 0)  // Fade in glass on scroll
    )
  }

  // MARK: - Tab Selector

  /// Available tabs based on media type filter - Watch Next only for TV shows
  private var availableTabs: [LibraryTab] {
    if selectedMediaType == "movie" {
      // Movies don't have Watch Next
      return [.watchlist, .watched]
    } else {
      // TV shows or "All" - show all tabs
      return LibraryTab.allCases
    }
  }

  private var tabButtons: some View {
    HStack(spacing: 8) {
      ForEach(availableTabs, id: \.self) { tab in
        Button {
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedTab = tab
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: tab.icon)
              .font(.system(size: 14, weight: .medium))
            Text(tab.rawValue)
              .font(.netflixSans(.medium, size: 14))
          }
          .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background {
            if selectedTab == tab {
              Capsule()
                .fill(Color.white.opacity(0.15))
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 4)
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
              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
          )
      }
    }
  }

  private var tabSelector: some View {
    // Fixed-width HStack - all tabs fit within available width
    HStack(spacing: 0) {
      ForEach(availableTabs, id: \.self) { tab in
        Button {
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred()
          withAnimation(.snappy) {
            selectedTab = tab
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: tab.icon)
              .font(.system(size: 12, weight: .medium))
            Text(tab.rawValue)
              .font(.netflixSans(.medium, size: 12))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background {
            if selectedTab == tab {
              Capsule()
                .fill(Color.white.opacity(0.15))
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
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
              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
          )
      }
    }
    .padding(.horizontal)  // Match other content margins
    .animation(.easeInOut(duration: 0.2), value: showTopBlur)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: selectedTab.emptyIcon)
        .font(.system(size: 60, weight: .light))
        .foregroundStyle(.gray.opacity(0.5))

      Text(selectedTab.emptyMessage)
        .font(.netflixSans(.bold, size: 20))
        .foregroundStyle(.white)

      Text(selectedTab.emptySubtitle)
        .font(.netflixSans(.medium, size: 14))
        .foregroundStyle(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Spacer()
    }
  }

  // MARK: - Content Grid

  private var contentGrid: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
      spacing: 12
    ) {
      ForEach(filteredItems, id: \.uniqueId) { item in
        let sourceId = "library_\(item.uniqueId)"
        let title = Title(
          id: item.titleId,
          title: item.mediaType == "movie" ? item.titleName : nil,
          name: item.mediaType == "tv" ? item.titleName : nil,
          posterPath: item.posterPath,
          voteAverage: item.userRating  // Pass partial rating if available
        )
        // Manually set media type as it's not in convenience init
        let _ = { title.mediaType = item.mediaType }()

        NavigationLink {
          TitleDetailView(title: title)
            .navigationTransition(.zoom(sourceID: sourceId, in: heroTransition))
        } label: {
          LibraryItemCard(item: item)
            .aspectRatio(2 / 3, contentMode: .fit)
            .matchedTransitionSource(id: sourceId, in: heroTransition)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
    .padding(.top, 10)
  }

  // MARK: - Watch Next List

  private var watchNextList: some View {
    VStack(spacing: 16) {
      ForEach(filteredItems, id: \.uniqueId) { item in
        let sourceId = "library_\(item.uniqueId)"
        let title = Title(
          id: item.titleId,
          title: nil,
          name: item.titleName,
          posterPath: item.posterPath,
          voteAverage: nil
        )
        let _ = { title.mediaType = "tv" }()

        NavigationLink {
          TitleDetailView(title: title)
            .navigationTransition(.zoom(sourceID: sourceId, in: heroTransition))
        } label: {
          WatchNextCard(item: item)
            .matchedTransitionSource(id: sourceId, in: heroTransition)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
    .padding(.top, 10)
  }
}

// MARK: - Library Item Card

@available(iOS 26.0, *)
struct LibraryItemCard: View {
  let item: UserLibraryItem

  // Episode progress (computed on demand for TV shows)
  private var episodeProgress: Int {
    guard item.mediaType == "tv" else { return 0 }
    return UserLibraryManager.shared.getShowProgress(showId: item.titleId)
  }

  var body: some View {
    // Poster Only (Text removed)
    AsyncImage(url: item.posterURL) { image in
      image
        .resizable()
        .scaledToFill()
    } placeholder: {
      Rectangle()
        .fill(Color.gray.opacity(0.3))
        .overlay {
          Image(systemName: item.mediaType == "tv" ? "play.tv" : "film")
            .font(.title)
            .foregroundStyle(.gray)
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 15))
    .overlay(
      RoundedRectangle(cornerRadius: 15)
        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
    )
    .overlay(alignment: .topTrailing) {
      // Rating badge if rated
      if let rating = item.userRating {
        HStack(spacing: 2) {
          Image(systemName: "star.fill")
            .font(.system(size: 10))
          Text(String(format: "%.1f", rating))
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.yellow.opacity(0.9))
        .clipShape(Capsule())
        .padding(6)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      // Episode progress for TV shows
      if item.mediaType == "tv" && episodeProgress > 0 {
        HStack(spacing: 3) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 10))
          Text("\(episodeProgress)")
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.9))
        .clipShape(Capsule())
        .padding(6)
      }
    }
  }
}

// MARK: - Watch Next Card

@available(iOS 26.0, *)
struct WatchNextCard: View {
  let item: UserLibraryItem
  @State private var isMarking = false
  @State private var currentStillURL: URL? = nil
  @State private var episodeName: String? = nil
  @State private var episodeAirDate: Date? = nil
  @State private var seasonNum: Int? = nil
  @State private var episodeNum: Int? = nil
  @State private var stillPath: String? = nil

  private var episodeProgress: Int {
    UserLibraryManager.shared.getShowProgress(showId: item.titleId)
  }

  private var nextEpisodeTarget: (season: Int, episode: Int)? {
    UserLibraryManager.shared.getNextEpisodeToWatch(showId: item.titleId)
  }

  private var daysUntilAir: Int? {
    guard let airDate = episodeAirDate else { return nil }
    let calendar = Calendar.current
    let fromDay = calendar.startOfDay(for: Date())
    let toDay = calendar.startOfDay(for: airDate)
    let days = calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
    return days >= 0 ? days : nil
  }

  var body: some View {
    HStack(spacing: 16) {
      // Episode still image or fallback to poster
      AsyncImage(url: currentStillURL ?? item.posterURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay {
            Image(systemName: "play.tv")
              .font(.title2)
              .foregroundStyle(.gray)
          }
      }
      .frame(width: 140, height: 80)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .task {
        // Fetch details for the *next* episode to watch
        if let target = nextEpisodeTarget {
          loadEpisodeDetails(season: target.season, episode: target.episode)
        }
      }

      // Show info
      VStack(alignment: .leading, spacing: 6) {
        Text(item.titleName)
          .font(.netflixSans(.bold, size: 17))
          .foregroundStyle(.white)
          .lineLimit(1)

        if let s = seasonNum, let e = episodeNum {
          if let name = episodeName, !name.isEmpty {
            Text("S\(s), E\(e) - \(name)")
              .font(.netflixSans(.medium, size: 14))
              .foregroundStyle(.gray)
              .lineLimit(2)
          } else {
            Text("S\(s), E\(e)")
              .font(.netflixSans(.medium, size: 14))
              .foregroundStyle(.gray)
          }

          // Countdown for future episodes
          if let days = daysUntilAir {
            HStack(spacing: 4) {
              Image(systemName: "clock")
                .font(.system(size: 10))
              Text(
                days == 0
                  ? "Airing today" : (days == 1 ? "Airing tomorrow" : "Airing in \(days) days")
              )
              .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.green)
          }
        } else {
          Text("\(episodeProgress) episodes watched")
            .font(.netflixSans(.medium, size: 14))
            .foregroundStyle(.gray)
        }
      }

      Spacer()

      // Eye button (only if released or airing today)
      if daysUntilAir == nil || daysUntilAir! <= 0 {
        Button {
          markCurrentEpisodeWatched()
        } label: {
          Image(systemName: "eye.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.white.opacity(0.8))
            .scaleEffect(isMarking ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarking)
        }
        .buttonStyle(.plain)
        .disabled(isMarking)
      } else {
        // Locked/Future icon
        Image(systemName: "lock.circle.fill")
          .font(.system(size: 36))
          .foregroundStyle(.gray.opacity(0.5))
      }
    }
    .padding(.vertical, 8)
  }

  // Logic to load episode
  private func loadEpisodeDetails(season: Int, episode: Int) {
    // Reset state for loading
    seasonNum = season
    episodeNum = episode

    Task {
      do {
        // Try fetching current target (e.g. S1 E5)
        let episodeData = try await TMDBClient.shared.fetchEpisodeDetails(
          tvId: item.titleId,
          seasonNumber: season,
          episodeNumber: episode
        )
        updateState(with: episodeData, season: season, episodeNumber: episode)
      } catch {
        // If failed (e.g. 404), maybe end of season? try next season S(n+1) E1
        // Only try this if we haven't already tried to increment season
        if episode > 1 {
          do {
            let nextSeason = season + 1
            let episodeData = try await TMDBClient.shared.fetchEpisodeDetails(
              tvId: item.titleId,
              seasonNumber: nextSeason,
              episodeNumber: 1
            )
            updateState(with: episodeData, season: nextSeason, episodeNumber: 1)
          } catch {
            print("Failed to find next episode for show \(item.titleId)")
          }
        }
      }
    }
  }

  // Helper to update state on main thread
  private func updateState(with episodeData: Title.Episode, season: Int, episodeNumber: Int) {
    Task { @MainActor in
      self.seasonNum = season
      self.episodeNum = episodeNumber
      self.episodeName = episodeData.name
      self.stillPath = episodeData.stillPath

      if let path = episodeData.stillPath {
        self.currentStillURL = URL(string: "https://image.tmdb.org/t/p/w300\(path)")
      } else {
        self.currentStillURL = nil
      }

      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      if let airDateStr = episodeData.airDate {
        self.episodeAirDate = formatter.date(from: airDateStr)
      } else {
        self.episodeAirDate = nil
      }
    }
  }

  // Logic to mark watched
  private func markCurrentEpisodeWatched() {
    guard let s = seasonNum, let e = episodeNum else { return }
    isMarking = true

    // Haptic
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()

    // Mark in DB with metadata
    UserLibraryManager.shared.markEpisodeWatched(
      showId: item.titleId,
      season: s,
      episode: e,
      episodeName: episodeName,
      stillPath: stillPath
    )

    // Short delay then refresh for next episode
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isMarking = false
      // Calculate next target (locally increment for immediate feedback)
      // Attempt to load next episode S, E+1
      loadEpisodeDetails(season: s, episode: e + 1)
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    LibraryView()
      .modelContainer(for: UserLibraryItem.self)
  }
}
