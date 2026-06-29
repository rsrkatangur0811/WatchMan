import SwiftData
import SwiftUI

struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var selectedTab: LibraryTab = .watchlist
  @State private var selectedMediaType: String? = nil
  @Query(sort: \UserLibraryItem.modifiedAt, order: .reverse) private var allItems: [UserLibraryItem]
  @Query private var watchedEpisodes: [WatchedEpisode]
  @State private var showTopBlur = false
  @State private var lastScrollOffset: CGFloat = 0
  @State private var isScrollingDown: Bool = false
  @State private var isSwitchingLibraryTab = false
  @State private var showLetterboxdSync = false
  @AppStorage("letterboxd.username") private var letterboxdUsername = ""
  @EnvironmentObject private var letterboxdSyncService: LetterboxdSyncService
  @Namespace private var heroTransition

  enum LibraryTab: String, CaseIterable {
    case watchNext = "Watch Next"
    case watchlist = "Watchlist"
    case watched = "Watched"

    var icon: String {
      switch self {
      case .watchNext: return "play"
      case .watchlist: return "bookmark"
      case .watched: return "checkmark"
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
      // Pre-compute set of show IDs with at least one watched episode (O(M) once)
      let showIdsWithProgress = Set(watchedEpisodes.map { $0.showId })
      // TV shows with at least one watched episode but not fully watched
      return typeFiltered.filter { item in
        guard item.mediaType == "tv" else { return false }
        return showIdsWithProgress.contains(item.titleId) && !item.isWatched
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
              if letterboxdSyncService.isSyncing {
                letterboxdProgressBanner
                  .padding(.horizontal)
                  .padding(.bottom, 10)
              }

              tabSelector
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .contentShape(Rectangle())
            .background(Color.black.opacity(0.001))
            .zIndex(10)
          }
        }
      }
      .ignoresSafeArea(edges: .top)  // Needed for custom header to reach top
      .compatibleOnScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showTopBlur = newValue > 20
        }
        // Hide-on-scroll detection
        let threshold: CGFloat = 10
        if newValue > lastScrollOffset + threshold {
          withAnimation(.easeOut(duration: 0.25)) {
            isScrollingDown = true
          }
        } else if newValue < lastScrollOffset - threshold {
          withAnimation(.easeOut(duration: 0.25)) {
            isScrollingDown = false
          }
        }
        lastScrollOffset = newValue
      }
      .preference(key: TabBarVisibilityPreferenceKey.self, value: isScrollingDown)
    }
    .toolbar(.hidden, for: .navigationBar)  // Hide standard nav bar
    .sheet(isPresented: $showLetterboxdSync) {
      LetterboxdSyncView()
    }
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
              .iconPillControl(minWidth: 50, height: 38)
          }
          .foregroundStyle(.white)
          .transition(.scale.combined(with: .opacity))

          // Selected Pill
	          Text(selected == "movie" ? "Movies" : "Shows")
	            .font(.netflixSans(.medium, size: 15))
	            .padding(.horizontal, 16)
	            .padding(.vertical, 8)
	            .background {
	              Capsule()
	                .fill(.clear)
	                .glassedEffect(in: Capsule())
	                .overlay {
	                  Capsule()
	                    .fill(Color.white.opacity(0.16))
	                }
	            }
	            .overlay {
	              Capsule()
	                .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.8)
	            }
	            .clipShape(Capsule())
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
	              .background {
	                Capsule()
	                  .fill(.clear)
	                  .glassedEffect(in: Capsule())
	              }
	              .overlay {
	                Capsule()
	                  .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.8)
	              }
	              .clipShape(Capsule())
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
	              .background {
	                Capsule()
	                  .fill(.clear)
	                  .glassedEffect(in: Capsule())
	              }
	              .overlay {
	                Capsule()
	                  .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.8)
	              }
	              .clipShape(Capsule())
          }
          .foregroundStyle(.white)
          .buttonStyle(.plain)
          .matchedGeometryEffect(id: "tv", in: heroTransition)
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 15)

      NavigationLink {
        TasteProfileView(items: allItems)
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "sparkles")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)

          VStack(alignment: .leading, spacing: 2) {
            Text("Taste Profile")
              .font(.netflixSans(.bold, size: 16))
              .foregroundStyle(.white)
            Text("Genres, decades, ratings, and recurring collaborators")
              .font(.netflixSans(.medium, size: 13))
              .foregroundStyle(.gray)
              .lineLimit(1)
          }

          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      .padding(.bottom, 10)

      Button {
        showLetterboxdSync = true
      } label: {
        HStack(spacing: 10) {
          Image("LetterboxdLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)

          VStack(alignment: .leading, spacing: 2) {
            Text(letterboxdUsername.isEmpty ? "Connect Letterboxd" : "Re-sync Letterboxd")
              .font(.netflixSans(.bold, size: 16))
              .foregroundStyle(.white)
            Text(letterboxdUsername.isEmpty ? "Import your public films and watchlist" : "@\(letterboxdUsername)")
              .font(.netflixSans(.medium, size: 13))
              .foregroundStyle(.gray)
          }

          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      .padding(.bottom, 12)
    }
    .padding(.top, 60)  // Safe area compensation
    .frame(maxWidth: .infinity, alignment: .leading)
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
		          isEnabled: showTopBlur
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
    )
  }

  // MARK: - Tab Selector

  private var letterboxdProgressBanner: some View {
    HStack(spacing: 10) {
      ProgressView()
        .tint(.white)
      Text(letterboxdSyncService.progressMessage.isEmpty ? "Syncing Letterboxd" : letterboxdSyncService.progressMessage)
        .font(.netflixSans(.medium, size: 13))
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color.white.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

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
          selectLibraryTab(tab)
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
	                .fill(.clear)
	                .glassedEffect(in: Capsule())
	                .overlay {
	                  Capsule()
	                    .fill(Color.white.opacity(0.15))
	                }
	            }
	          }
        }
        .buttonStyle(.plain)
      }
    }
	    .padding(.horizontal, 4)
	    .padding(.vertical, 4)
	    .background {
	      Capsule()
	        .fill(.clear)
	        .glassedEffect(in: Capsule())
	        .overlay {
	          ZStack {
	            Capsule()
	              .fill(Color.black.opacity(0.12))
	            Capsule()
	              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
	          }
	        }
	    }
  }

  private var tabSelector: some View {
    // Fixed-width HStack - all tabs fit within available width
    HStack(spacing: 0) {
      ForEach(availableTabs, id: \.self) { tab in
        Button {
          selectLibraryTab(tab)
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
	                .fill(.clear)
	                .glassedEffect(in: Capsule())
	                .overlay {
	                  Capsule()
	                    .fill(Color.white.opacity(0.15))
	                }
	            }
	          }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
      }
    }
	    .padding(4)
	    .background {
	      Capsule()
	        .fill(.clear)
	        .glassedEffect(in: Capsule())
	        .overlay {
	          ZStack {
	            Capsule()
	              .fill(Color.black.opacity(0.12))
	            Capsule()
	              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
	          }
	        }
	    }
    .padding(.horizontal)  // Match other content margins
    .animation(.easeInOut(duration: 0.2), value: showTopBlur)
  }

  private func selectLibraryTab(_ tab: LibraryTab) {
    guard selectedTab != tab else { return }

    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.impactOccurred()
    isSwitchingLibraryTab = true
    withAnimation(.snappy) {
      selectedTab = tab
    }

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 250_000_000)
      isSwitchingLibraryTab = false
    }
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
        let title = title(from: item)

        NavigationLink {
          TitleDetailView(
            title: title,
            zoomNamespace: heroTransition,
            zoomSourceID: sourceId
          )
        } label: {
          LibraryItemCard(item: item)
            .aspectRatio(2 / 3, contentMode: .fit)
            .matchedTransitionSource(id: sourceId, in: heroTransition)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isSwitchingLibraryTab)
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
        let title = title(from: item)

        NavigationLink {
          TitleDetailView(
            title: title,
            zoomNamespace: heroTransition,
            zoomSourceID: sourceId
          )
        } label: {
          WatchNextCard(item: item)
            .matchedTransitionSource(id: sourceId, in: heroTransition)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isSwitchingLibraryTab)
      }
    }
    .padding(.horizontal)
    .padding(.top, 10)
  }

  private func title(from item: UserLibraryItem) -> Title {
    var title = Title(
      id: item.titleId,
      title: item.mediaType == "movie" ? item.titleName : nil,
      name: item.mediaType == "tv" ? item.titleName : nil,
      posterPath: item.posterPath,
      voteAverage: item.userRating
    )
    title.mediaType = item.mediaType
    return title
  }
}

// MARK: - Library Item Card

struct LibraryItemCard: View {
  let item: UserLibraryItem

  // Episode progress (computed on demand for TV shows)
  private var episodeProgress: Int {
    guard item.mediaType == "tv" else { return 0 }
    return UserLibraryManager.shared.getShowProgress(showId: item.titleId)
  }

  var body: some View {
    // Poster Only (Text removed)
    TMDBImage(path: item.posterPath, size: .w500) { image in
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

  private var latestWatchedEpisode: (season: Int, episode: Int)? {
    UserLibraryManager.shared.getLatestWatchedEpisode(showId: item.titleId)
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
      TMDBImage(path: currentStillURL?.absoluteString ?? item.posterPath, size: .w300) { image in
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
        if let latest = latestWatchedEpisode {
          await loadNextEpisodeDetails(after: latest)
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
          Image(systemName: "eye")
            .font(.system(size: 18, weight: .semibold))
            .iconPillControl(minWidth: 58, height: 42, fillOpacity: 0.28)
            .scaleEffect(isMarking ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarking)
        }
        .buttonStyle(.plain)
        .disabled(isMarking)
      } else {
        // Locked/Future icon
        Image(systemName: "lock.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.gray.opacity(0.7))
          .frame(minWidth: 58)
          .frame(height: 42)
          .background {
            Capsule()
              .fill(.black.opacity(0.18))
          }
          .clipShape(Capsule())
      }
    }
    .padding(.vertical, 8)
  }

  private func loadNextEpisodeDetails(after latest: (season: Int, episode: Int)) async {
    seasonNum = latest.season
    episodeNum = latest.episode + 1

    do {
      let currentSeason = try await TMDBClient.shared.fetchSeasonDetails(
        tvId: item.titleId,
        seasonNumber: latest.season
      )
      let currentEpisodes = currentSeason.episodes

      if let nextEpisode = currentEpisodes
        .filter({ ($0.episodeNumber ?? 0) > latest.episode })
        .sorted(by: { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) })
        .first,
        let episodeNumber = nextEpisode.episodeNumber {
        updateState(with: nextEpisode, season: latest.season, episodeNumber: episodeNumber)
        return
      }

      let nextSeason = latest.season + 1
      let followingSeason = try await TMDBClient.shared.fetchSeasonDetails(
        tvId: item.titleId,
        seasonNumber: nextSeason
      )
      let followingEpisodes = followingSeason.episodes

      if let firstEpisode = followingEpisodes
        .filter({ ($0.episodeNumber ?? 0) > 0 })
        .sorted(by: { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) })
        .first,
        let episodeNumber = firstEpisode.episodeNumber {
        updateState(with: firstEpisode, season: nextSeason, episodeNumber: episodeNumber)
      }
    } catch {
      print("Failed to find next episode for show \(item.titleId)")
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
      Task {
        await loadNextEpisodeDetails(after: (season: s, episode: e))
      }
    }
  }
}

#Preview {
  LibraryView()
    .modelContainer(for: [UserLibraryItem.self, WatchedEpisode.self])
}
