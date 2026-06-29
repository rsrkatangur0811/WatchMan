import SafariServices
import SwiftUI


private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct TitleDetailView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) var modelContext
  @State private var viewModel: DetailViewModel
  @State private var selectedTrailer: Video?
  @State private var currentBackdropColor: Color = .black
  @State private var selectedReview: Review?
  @State private var randomBackdrop: String?
  @State private var showTopBlur = false  // For scroll-based glass effect
  @State private var scrollProgress: Double = 0  // Proportional fade opacity
  @State private var showBottomBlur = true  // Default to true, fades out when reaching bottom
  @State private var bottomScrollProgress: Double = 1.0

  // Namespace for internal zoom transitions
  @Namespace private var detailNamespace

  // Library tracking
  @State private var isInWatchlist = false
  @State private var isWatched = false
  @State private var userRating: Double?
  @State private var showRatingSheet = false

  // Episode tracking
  @State private var watchedEpisodes: Set<Int> = []
  @State private var showMarkAllAlert = false
  @State private var showMarkPreviousAlert = false
  @State private var pendingEpisodeNumber: Int? = nil

  // Zoom transition parameters — passed from source views to enable fluid zoom
  var zoomNamespace: Namespace.ID? = nil
  var zoomSourceID: String? = nil

  init(title: Title, zoomNamespace: Namespace.ID? = nil, zoomSourceID: String? = nil) {
    self._viewModel = State(wrappedValue: DetailViewModel(title: title))
    self.zoomNamespace = zoomNamespace
    self.zoomSourceID = zoomSourceID
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .loading:
        ProgressView("Loading details...")
          .tint(.white)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

      case .failed(let error):
        VStack(spacing: 20) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.largeTitle)
            .foregroundStyle(.yellow)
          Text("Failed to load details")
            .font(.title2)
            .bold()
            .foregroundStyle(.white)
          Text(error.localizedDescription)
            .font(.body)
            .foregroundStyle(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          Button {
            Task {
              await viewModel.loadAllData()
            }
          } label: {
            Text("Retry")
              .font(.headline)
          }
	          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      case .success:
        ZStack(alignment: .top) {
          ScrollView {
            VStack(alignment: .center, spacing: 20) {
              // MARK: - Header Section
              VStack(alignment: .leading, spacing: 0) {
                // 1. Backdrop Background
                GeometryReader { proxy in
                  let minY = proxy.frame(in: .named("titleDetailScroll")).minY
                  let stretch = max(0, minY)

                  if let path = randomBackdrop ?? viewModel.title.backdropPath
                    ?? viewModel.title.posterPath
                  {
                    TMDBImage(path: path, size: .w1280) { image in
                      image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: 300 + stretch)
                        .scaleEffect(1 + stretch / 600, anchor: .center)
                        .clipped()
                        .mask(
                          LinearGradient(
                            colors: [.black, .black, .black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                        )
                        .offset(y: -stretch)
                    } placeholder: {
                      Color.black
                        .frame(width: proxy.size.width, height: 300 + stretch)
                        .offset(y: -stretch)
                    }
                  }
                }
                .frame(height: 300)

                // 2. Info Overlay (Title, Director, Poster, etc.)
                HStack(alignment: .top, spacing: 16) {
                  // Left Side: Info & Actions
                  VStack(alignment: .leading, spacing: 10) {
                    // Title
                    if let logos = viewModel.title.images?.logos, !logos.isEmpty,
                      let logoPath = logos.first?.filePath
                    {
                      TMDBImage(path: logoPath, size: .w500) { image in
                        image.resizable().scaledToFit().frame(height: 80, alignment: .leading)
                      } placeholder: {
                        Text(viewModel.title.name ?? viewModel.title.title ?? "")
                          .font(.netflixSans(.bold, size: 28))
                          .foregroundStyle(.white)
                          .multilineTextAlignment(.leading)
                      }
                    } else {
                      Text(viewModel.title.name ?? viewModel.title.title ?? "")
                        .font(.netflixSans(.bold, size: 28))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    }

                    // Metadata: Year • Directed By
                    VStack(alignment: .leading, spacing: 4) {
                      HStack(spacing: 6) {
                        if let date = viewModel.title.releaseDate {
                          Text(String(date.prefix(4)))  // Just the Year
                            .foregroundStyle(.white.opacity(0.7))
                        }

                        // Show DIRECTED BY for movies, CREATED BY for TV shows
                        if viewModel.crew.first(where: { $0.job == "Director" }) != nil {
                          Text("•")
                            .foregroundStyle(.white.opacity(0.7))
                          Text("DIRECTED BY")
                            .foregroundStyle(.white.opacity(0.7))
                        } else if let creators = viewModel.title.createdBy, !creators.isEmpty {
                          // Use dedicated createdBy field for TV shows
                          Text("•")
                            .foregroundStyle(.white.opacity(0.7))
                          Text("CREATED BY")
                            .foregroundStyle(.white.opacity(0.7))
                        }
                      }
                      .font(.netflixSans(.light, size: 12))

                      // Show director name for movies, creator name for TV shows
                      if let director = viewModel.crew.first(where: { $0.job == "Director" }) {
                        Text(director.name)
                          .font(.netflixSans(.bold, size: 16))
                          .foregroundStyle(.white)
                      } else if let creators = viewModel.title.createdBy,
                        let firstCreator = creators.first
                      {
                        // Use dedicated createdBy field
                        Text(firstCreator.name)
                          .font(.netflixSans(.bold, size: 16))
                          .foregroundStyle(.white)
                      }
                    }

                    // Runtime/Seasons • Cert
                    HStack(spacing: 6) {
	                      if let runtime = viewModel.title.runtime, runtime > 0 {
	                        Text("\(runtime) mins")
	                          .font(.netflixSans(.light, size: 14))
	                          .foregroundStyle(.white.opacity(0.7))
	                      } else if let seasons = viewModel.title.numberOfSeasons, seasons > 0 {
	                        Text(seasonCountLabel(for: seasons))
	                          .font(.netflixSans(.light, size: 14))
	                          .foregroundStyle(.white.opacity(0.7))
	                      }

                      if let cert = viewModel.title.certification, !cert.isEmpty {
                        Text("•")
                          .foregroundStyle(.gray)
                        Text(cert)
                          .font(.netflixSans(.medium, size: 12))
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.gray.opacity(0.3))
                          .cornerRadius(4)
                          .foregroundStyle(.white)
                      }
                    }

                    // Budget
                    if let budget = viewModel.title.budget, budget > 0 {
                      Text("Budget: " + NumberFormatter.compactCurrency(value: budget))
                        .font(.netflixSans(.light, size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    }

                  }
                  .frame(maxWidth: .infinity, alignment: .leading)

                  // Right Side: Poster
                  if let poster = viewModel.title.posterPath {
                    TMDBImage(path: poster, size: .w500) { image in
                      image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                          RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                              LinearGradient(
                                colors: [
                                  .white.opacity(0.5),
                                  .white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                              lineWidth: 0.5
                            )
                        )
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    } placeholder: {
                      RoundedRectangle(cornerRadius: 22)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 180)
                    }
                  }
                }

                .padding(.horizontal, 24)
                .padding(.top, 20)
              }

              // MARK: - Synopsis
              VStack(alignment: .leading, spacing: 16) {
                // MARK: - User Actions
                HStack(spacing: 12) {
                  // Watchlist Button
                  Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                      isInWatchlist.toggle()
                      UserLibraryManager.shared.toggleWatchlist(for: viewModel.title)
                    }
                  } label: {
                    HStack(spacing: 8) {
                      Image(systemName: isInWatchlist ? "checkmark" : "plus")
                        .font(.system(size: 18, weight: .medium))
                      Text(isInWatchlist ? "In Watchlist" : "Watchlist")
                        .font(.netflixSans(.medium, size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                      Capsule()
                        .fill(isInWatchlist ? Color(red: 1.0, green: 0.18, blue: 0.39).opacity(0.5) : Color.clear)
                        .glassedEffect(in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                  }
                  .buttonStyle(.plain)

                  // Watched Button
                  if viewModel.isReleased {
                    Button {
                      let isTVShow = viewModel.title.name != nil

                      if isTVShow && !isWatched {
                        // For TV shows, show confirmation dialog
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showMarkAllAlert = true
                      } else {
                        // For movies or un-watching, direct toggle
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                          isWatched.toggle()
                          UserLibraryManager.shared.toggleWatched(for: viewModel.title)

                          if isWatched {
                            isInWatchlist = false
                          }
                        }
                      }
                    } label: {
                      HStack(spacing: 8) {
                        Image(systemName: isWatched ? "checkmark" : "eye")
                          .font(.system(size: 18, weight: .medium))
                        Text(isWatched ? "Watched" : "Watch")
                          .font(.netflixSans(.medium, size: 16))
                      }
                      .frame(maxWidth: .infinity)
                      .frame(height: 52)
                      .background {
                        Capsule()
                          .fill(isWatched ? Color(red: 0.0, green: 0.68, blue: 1.0).opacity(0.5) : Color.clear)
                          .glassedEffect(in: Capsule())
                      }
                      .foregroundStyle(.white)
                      .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                  } else {
                    // Unreleased Button
                    Button {} label: {
                      HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                          .font(.system(size: 18, weight: .medium))
                        Text("Unreleased")
                          .font(.netflixSans(.medium, size: 16))
                          .lineLimit(1)
                          .minimumScaleFactor(0.8)
                      }
                      .frame(maxWidth: .infinity)
                      .frame(height: 52)
                      .background {
                        Capsule()
                          .fill(.clear)
                          .glassedEffect(in: Capsule())
                      }
                      .foregroundStyle(.gray)
                      .clipShape(Capsule())
                      .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                      )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                  }
                }

                Text(viewModel.title.overview ?? "")
                  .font(.netflixSans(.medium, size: 16))  // Slightly reduced size
                  .foregroundStyle(.white.opacity(0.8))
                  .multilineTextAlignment(.leading)

                // Ratings
                RatingsInfoView(title: viewModel.title)
                  .padding(.top, 4)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 24)
              .padding(.top, 10)

              // MARK: - Remaining Content (animated group)
              Group {
              // MARK: - Watch Providers
              if !viewModel.providers.isEmpty {
                VStack(alignment: .leading) {
                  Text("Watch on")
                    .font(.netflixSans(.bold, size: 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                  ScrollView(.horizontal, showsIndicators: false) {
	                    HStack(spacing: 15) {
	                      ForEach(viewModel.providers) { provider in
	                        providerCard(provider)
	                      }
	                    }
                    .padding(.horizontal, 24)
                  }
                }
              }

              // MARK: - Trailers
              if !viewModel.videos.isEmpty {
                VStack(alignment: .leading) {
                  Text("Trailers")
                    .font(.netflixSans(.bold, size: 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                      ForEach(viewModel.videos) { video in
                        TrailerItemView(video: video)
                          .onTapGesture {
                            selectedTrailer = video
                          }
                      }
                    }
                    .padding(.horizontal, 24)
                  }
                }
              }

              // MARK: - TV Seasons
              if let seasons = viewModel.title.seasons, !seasons.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                  HStack {
                    Text("Seasons")
                      .font(.netflixSans(.bold, size: 20))
                      .foregroundStyle(.white)

                    // Season progress indicator
                    if viewModel.selectedSeason != nil {
                      let total = viewModel.episodes.count
                      let watched = watchedEpisodes.count
                      if total > 0 {
                        Text("\(watched)/\(total)")
                          .font(.netflixSans(.medium, size: 14))
                          .foregroundStyle(watched == total ? .green : .gray)
                      }
                    }

                    Spacer()

                    Menu {
                      ForEach(seasons) { season in
                        Button(season.name) {
                          let impact = UIImpactFeedbackGenerator(style: .light)
                          impact.impactOccurred()
                          viewModel.selectSeason(season)
                        }
                      }

                      Divider()

                      // Mark all watched button
                      if let season = viewModel.selectedSeason, !viewModel.episodes.isEmpty {
                        let allWatched = watchedEpisodes.count == viewModel.episodes.count
                        Button {
                          let impact = UIImpactFeedbackGenerator(style: .medium)
                          impact.impactOccurred()
                          if allWatched {
                            // Unmark all
                            UserLibraryManager.shared.unmarkSeasonWatched(
                              showId: viewModel.title.stableNumericID,
                              season: season.seasonNumber
                            )
                            watchedEpisodes.removeAll()
                          } else {
                            // Mark all
                            let episodeNums = viewModel.episodes.compactMap { $0.episodeNumber }
                            UserLibraryManager.shared.markSeasonWatched(
                              showId: viewModel.title.stableNumericID,
                              season: season.seasonNumber,
                              episodeNumbers: episodeNums
                            )
                            watchedEpisodes = Set(episodeNums)
                          }
                        } label: {
                        Label(
                          allWatched ? "Unmark All Watched" : "Mark All Watched",
                          systemImage: allWatched ? "xmark" : "checkmark"
                        )
                        }
                      }
                    } label: {
                      HStack {
                        Text(viewModel.selectedSeason?.name ?? "Select Season")
                        Image(systemName: "chevron.down")
                      }
                      .font(.netflixSans(.medium, size: 15))
                      .foregroundStyle(.white)
                      .padding(.horizontal, 14)
                      .frame(height: 42)
                      .background {
                        Capsule()
                          .fill(.black.opacity(0.18))
                          .glassedEffect(in: Capsule())
                      }
                      .clipShape(Capsule())
                      .overlay {
                        Capsule()
                          .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                      }
                    }
                    .buttonStyle(.plain)
                  }
                  .padding(.horizontal, 24)

                  if !viewModel.episodes.isEmpty {
	                    ScrollView(.horizontal, showsIndicators: false) {
	                      HStack(alignment: .top, spacing: 20) {
	                        ForEach(viewModel.episodes) { episode in
	                          episodeCard(episode)
	                        }
	                      }
                      .padding(.horizontal, 24)
                    }
                  }
                }
              }

              // MARK: - Cast & Crew
              if !viewModel.cast.isEmpty || !viewModel.crew.filter({ $0.job == "Director" }).isEmpty
              {
                VStack(alignment: .leading) {
                  Text("Cast & Crew")
                    .font(.netflixSans(.bold, size: 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                  ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 20) {
                      // Directors first
	                      ForEach(viewModel.crew.filter { $0.job == "Director" }) { crew in
	                        NavigationLink(
	                          destination: PersonDetailView(
	                            personId: crew.id, name: crew.name, profileURL: crew.profileURL)
	                        ) {
	                          personCreditCard(
	                            name: crew.name,
	                            subtitle: "Director",
	                            profileURL: crew.profileURL
	                          )
	                        }
	                        .buttonStyle(.plain)
	                      }

                      // Then cast members
	                      ForEach(Array(viewModel.cast.prefix(20).enumerated()), id: \.offset) { _, cast in
	                        NavigationLink(
	                          destination: PersonDetailView(
	                            personId: cast.id, name: cast.name, profileURL: cast.profileURL)
	                        ) {
	                          personCreditCard(
	                            name: cast.name,
	                            subtitle: cast.character,
	                            profileURL: cast.profileURL
	                          )
	                        }
	                        .buttonStyle(.plain)
	                      }
                    }
                    .padding(.horizontal, 24)
                  }
                }
              }


	              // MARK: - Reviews & Recommendations (Keep existing logic)
	              Group {
	                reviewsSection

                  // MARK: - Production Companies
                  let companiesWithLogos = viewModel.productionCompanies.filter { $0.logoURL != nil }
                  if !companiesWithLogos.isEmpty {
                    VStack(alignment: .leading) {
                      Text(companiesWithLogos.count == 1 ? "Production Company" : "Production Companies")
                        .font(.netflixSans(.bold, size: 20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                      ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                          ForEach(companiesWithLogos) { company in
                            NavigationLink(destination: CompanyTitlesView(company: company)) {
                              productionCompanyCard(company)
                            }
                            .buttonStyle(.plain)
                          }
                        }
                        .padding(.horizontal, 24)
                      }
                    }
                  }

	                // MARK: - This Series (Above Recommended)
	                collectionSection

	                recommendationsSection

	                // MARK: - More from Director/Creator (Below Recommended)
	                directorCreditsSection
	              }
              }

              Spacer(minLength: 50)
            }
          }
          .compatibleOnScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
          } action: { _, offset in
            let scrollDown = offset > 10
            let progress = max(0, min(1, offset / 80))
            showTopBlur = scrollDown
            scrollProgress = progress
          }
          .scrollBounceBehavior(.always)
          .ignoresSafeArea(edges: .top)
	          .scrollEdgeEffectSoftCompat(for: .top)
          .coordinateSpace(name: "titleDetailScroll")

        }
        .overlay(alignment: .top) {
          if showTopBlur {
            Rectangle()
              .fill(
                LinearGradient(
                  colors: [
                    Color.black,  // 100%
                    Color.black.opacity(0.5),  // 50%
                    Color.black.opacity(0),  // 0%
                    Color.clear,
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .frame(height: 220)
              .blur(radius: 12)
              .padding(.top, -60)  // Force mask UP into notch area physically
              .opacity(scrollProgress)
              .animation(
                .easeOut(duration: 0.18), value: scrollProgress
              )
              .allowsHitTesting(false)
              .ignoresSafeArea(edges: .top)
          }
        }
        .overlay(alignment: .topLeading) {
          detailBackButton
            .padding(.top, 54)
            .padding(.leading, 18)
        }
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  Color.clear,
                  Color.black.opacity(0.0),  // 0%
                  Color.black.opacity(0.5),  // 50%
                  Color.black,  // 100%
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(height: 220)
            .blur(radius: 12)
            .padding(.bottom, -60)  // Force mask DOWN into home indicator area
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .vertical)
        .toolbarBackground(.hidden, for: .navigationBar)  // Release safe area ownership
      }
	    }
	    .background {
	      detailBackground
	    }
    .overlay(alignment: .bottom) {
      ratingPillOverlay
        .padding(.bottom, 10)
    }
    .navigationBarBackButtonHidden(true)
    .enablesInteractivePopGesture()
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .if(zoomNamespace != nil && zoomSourceID != nil) { view in
      view.navigationTransition(.zoom(sourceID: zoomSourceID!, in: zoomNamespace!))
    }
    // Mark Previous Episodes Alert
    .alert("Mark Previous Episodes?", isPresented: $showMarkPreviousAlert) {
      Button("This Episode Only") {
        if let episodeNum = pendingEpisodeNumber {
          markSingleEpisode(episodeNum)
        }
        pendingEpisodeNumber = nil
      }
      Button("Mark All Previous") {
        if let episodeNum = pendingEpisodeNumber {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            markEpisodeAndPrevious(episodeNum)
          }
        }
        pendingEpisodeNumber = nil
      }
      Button("Cancel", role: .cancel) {
        pendingEpisodeNumber = nil
      }
    } message: {
      Text("Mark only this episode or also all earlier episodes as watched?")
    }
    // Mark All Episodes Alert (for main Watch button)
    .alert("Mark All Episodes?", isPresented: $showMarkAllAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Mark All") {
        markAllEpisodesAllSeasons()
      }
    } message: {
      Text("This will mark all episodes from all seasons as watched.")
    }
    .task {
      await loadCurrentTitleData()
    }
    .overlay {
      if let review = selectedReview {
        FullReviewView(review: review) {
          withAnimation {
            selectedReview = nil
          }
        }
      }
    }
    .sheet(item: $selectedTrailer) { video in
      if let url = video.youtubeURL {
        SafariView(url: url).ignoresSafeArea()
      } else {
        Text("Video unavailable")
      }
    }
    .onChange(of: viewModel.title) { _, newTitle in
      if let backdrops = newTitle.images?.backdrops, !backdrops.isEmpty {
        // Prioritize highest-voted textless (no language) backdrop
        let textlessBackdrops = backdrops.filter { $0.iso6391 == nil }
        if let bestTextless = textlessBackdrops.max(by: {
          ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0)
        }) {
          randomBackdrop = bestTextless.filePath
        } else if let bestAny = backdrops.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) })
        {
          // Fallback to highest-voted of any language
          randomBackdrop = bestAny.filePath
        } else {
          randomBackdrop = newTitle.backdropPath
        }
      } else {
        randomBackdrop = newTitle.backdropPath
      }

      // Auto-select the latest season for TV shows if not already selected
      if let seasons = newTitle.seasons, !seasons.isEmpty, viewModel.selectedSeason == nil {
        if let lastSeason = seasons.last {
          viewModel.selectSeason(lastSeason)
        }
      }
    }
    .onChange(of: viewModel.selectedSeason) { _, newSeason in
      // Load watched episodes for the new season
      if let season = newSeason {
        let watched = UserLibraryManager.shared.getWatchedEpisodes(
          showId: viewModel.title.stableNumericID,
          season: season.seasonNumber
        )
        watchedEpisodes = Set(watched)
      } else {
        watchedEpisodes.removeAll()
      }
    }
  }

  private func loadCurrentTitleData() async {
    UserLibraryManager.shared.setModelContext(modelContext)

    let titleId = viewModel.title.stableNumericID
    let mediaType = viewModel.title.name != nil ? "tv" : "movie"
    isInWatchlist = UserLibraryManager.shared.isInWatchlist(titleId: titleId, mediaType: mediaType)
    isWatched = UserLibraryManager.shared.isWatched(titleId: titleId, mediaType: mediaType)
    userRating = UserLibraryManager.shared.getRating(titleId: titleId, mediaType: mediaType)
    watchedEpisodes.removeAll()

    await viewModel.loadAllData()

    if let path = viewModel.title.backdropPath ?? viewModel.title.posterPath {
      updateColor(for: path)
    }
  }

  // MARK: - Scroll Blur Components (Compiler-Safe)
  private var topBlurOverlay: some View {
    Group {
      if showTopBlur {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [
                Color.black.opacity(0.95),
                Color.black.opacity(0.6),
                Color.black.opacity(0),
                Color.clear,
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(height: 160)
          .blur(radius: 12)
          .opacity(scrollProgress)
          .animation(
            .interactiveSpring(response: 0.25, dampingFraction: 0.85), value: scrollProgress
          )
          .allowsHitTesting(false)
          .ignoresSafeArea(.container, edges: .top)
      }
    }
  }

  // MARK: - Blurred Background View
  @ViewBuilder
  private var blurredBackground: some View {
    if let path = randomBackdrop ?? viewModel.title.backdropPath ?? viewModel.title.posterPath {
      TMDBImage(path: path, size: .w500) { image in
        image
          .resizable()
          .scaledToFill()
          .blur(radius: 60)
          .overlay(Color.black.opacity(0.5))
      } placeholder: {
        Color.black
      }
      .ignoresSafeArea()
    } else {
      Color.black.ignoresSafeArea()
    }
  }

  // Simple date formatter helper
  func formatDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"  // API format usually
    if let date = formatter.date(from: dateString) {
      formatter.dateFormat = "MMMM d"
      return formatter.string(from: date)
    }
    return dateString
  }

  private func updateColor(for path: String) {
    let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
    guard let url = URL(string: "https://image.tmdb.org/t/p/w500\(cleanPath)") else { return }

    Task {
      guard let uiImage = try? await ImageLoader.cachedImage(for: url),
            let avgColor = uiImage.dominantBrightColor else { return }
      withAnimation {
        // Darken the color a bit for background suitability
        self.currentBackdropColor = Color(uiColor: avgColor).opacity(0.3)
      }
    }
  }
  @ViewBuilder
  private var ratingPillOverlay: some View {
    if viewModel.isReleased {
      FloatingRatingPill(rating: $userRating) { newRating in
        userRating = newRating
        UserLibraryManager.shared.setRating(for: viewModel.title, rating: newRating)

        // Rating implies usage, so mark as watched and remove from watchlist
        if let r = newRating, r > 0 {
          withAnimation {
            isWatched = true
            isInWatchlist = false
          }
        }
      }
    }
  }
}

struct SafariView: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> SFSafariViewController {
    return SFSafariViewController(url: url)
  }
  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Episode Helper Functions
extension TitleDetailView {
  private func seasonCountLabel(for seasons: Int) -> String {
    "\(seasons) Season\(seasons == 1 ? "" : "s")"
  }

  @ViewBuilder
  private var detailBackground: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      blurredBackground
    }
  }

  @ViewBuilder
  private func providerCard(_ provider: ProviderItem) -> some View {
    VStack {
      if provider.providerName.contains("Hotstar") || provider.providerName.contains("JioCinema") {
        Image("JioHotstarLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 50, height: 50)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        AsyncImage(url: provider.logoURL) { image in
          image
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } placeholder: {
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 50, height: 50)
        }
      }

      Text(provider.providerName)
        .font(.netflixSans(.medium, size: 11))
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(1)
        .frame(maxWidth: 60)
    }
  }

  @ViewBuilder
  private func productionCompanyCard(_ company: ProductionCompany) -> some View {
    if let logoURL = company.logoURL {
      ZStack {
        Capsule()
          .fill(Color.white.opacity(0.92))
          .frame(width: 132, height: 54)

        AsyncImage(url: logoURL) { image in
          image
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(width: 132, height: 54)
        } placeholder: {
          ProgressView()
            .tint(.black.opacity(0.6))
        }
      }
      .overlay {
        Capsule()
          .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
      }
      .contentShape(Capsule())
      .accessibilityLabel(company.name)
    }
  }

  @ViewBuilder
  private var reviewsSection: some View {
    if !viewModel.reviews.isEmpty {
      VStack(alignment: .leading) {
        Text("Reviews")
          .font(.netflixSans(.bold, size: 20))
          .foregroundStyle(.white)
          .padding(.horizontal, 24)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 15) {
            ForEach(viewModel.reviews) { review in
              ReviewCardView(review: review)
                .onTapGesture {
                  withAnimation {
                    selectedReview = review
                  }
                }
            }
          }
          .padding(.horizontal, 24)
        }
      }
    }
  }

  @ViewBuilder
  private var collectionSection: some View {
    let sectionTitle = viewModel.title.belongsToCollection?.name ?? "This Series"
    titleCarouselSection(
      title: sectionTitle,
      sourcePrefix: "collection",
      titles: viewModel.collectionTitles
    )
  }

  @ViewBuilder
  private var recommendationsSection: some View {
    titleCarouselSection(
      title: "Recommended",
      sourcePrefix: "rec",
      titles: viewModel.recommendations
    )
  }

  @ViewBuilder
  private var directorCreditsSection: some View {
    if let name = viewModel.directorName {
      titleCarouselSection(
        title: "More from \(name)",
        sourcePrefix: "director",
        titles: viewModel.directorCredits
      )
    }
  }

  @ViewBuilder
  private func titleCarouselSection(
    title: String,
    sourcePrefix: String,
    titles: [Title]
  ) -> some View {
    if !titles.isEmpty {
      VStack(alignment: .leading) {
        Text(title)
          .font(.netflixSans(.bold, size: 20))
          .foregroundStyle(.white)
          .padding(.horizontal, 24)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 15) {
            ForEach(titles, id: \.stableDisplayID) { title in
              let sourceID = "\(sourcePrefix)_\(title.stableDisplayID)"
              NavigationLink(destination: TitleDetailView(
                title: title,
                zoomNamespace: detailNamespace,
                zoomSourceID: sourceID
              )) {
                SmallTitleCard(title: title, namespace: detailNamespace, sourceID: sourceID)
              }
            }
          }
          .padding(.horizontal, 24)
        }
      }
    }
  }

  private var detailBackButton: some View {
    Button {
      dismiss()
    } label: {
      detailControlPill(systemImage: "chevron.left")
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Back")
  }

  private func detailControlPill(systemImage: String, title: String? = nil) -> some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .bold))

      if let title {
        Text(title)
          .font(.netflixSans(.medium, size: 15))
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 14)
    .frame(minWidth: title == nil ? 58 : nil)
    .frame(height: 42)
    .background {
      Capsule()
        .fill(.black.opacity(0.18))
        .glassedEffect(in: Capsule())
    }
    .clipShape(Capsule())
    .overlay {
      Capsule()
        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
  }

  @ViewBuilder
  private func personCreditCard(
    name: String,
    subtitle: String?,
    profileURL: URL?
  ) -> some View {
    VStack(spacing: 6) {
      AsyncImage(url: profileURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.gray.opacity(0.3)
      }
      .frame(width: 80, height: 120)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

      VStack(spacing: 2) {
        Text(name)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(width: 80)
          .fixedSize(horizontal: false, vertical: true)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
            .frame(width: 80)
        }
      }
      .frame(minHeight: 50)
    }
  }

  @ViewBuilder
  private func episodeCard(_ episode: Title.Episode) -> some View {
    let episodeNum = episode.episodeNumber ?? 0
    let isWatched = watchedEpisodes.contains(episodeNum)
    let isReleased = isEpisodeReleased(episode)
    let overview = episode.overview ?? "No description available."
    let titleColor: Color = isWatched ? .green : (isReleased ? .white : .gray)

    VStack(alignment: .leading, spacing: 8) {
      episodeImageStack(
        episode: episode,
        episodeNum: episodeNum,
        isWatched: isWatched,
        isReleased: isReleased
      )

      Text("\(episodeNum). \(episode.name)")
        .font(.netflixSans(.bold, size: 15))
        .foregroundStyle(titleColor)
        .lineLimit(1)

      Text(overview)
        .font(.netflixSans(.medium, size: 12))
        .foregroundStyle(.gray)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
    .frame(width: 220)
  }

  @ViewBuilder
  private func episodeImageStack(
    episode: Title.Episode,
    episodeNum: Int,
    isWatched: Bool,
    isReleased: Bool
  ) -> some View {
    ZStack(alignment: .topTrailing) {
      AsyncImage(url: episode.stillURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        ZStack {
          Rectangle().fill(Color.gray.opacity(0.3))
          Image(systemName: "tv.fill")
            .foregroundStyle(.white.opacity(0.5))
        }
      }
      .frame(width: 220, height: 125)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            isWatched ? Color.green.opacity(0.6) : Color.white.opacity(0.1),
            lineWidth: isWatched ? 2 : 1
          )
      )
      .overlay {
        if !isReleased {
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.6))
        }
      }

      if isReleased {
        episodeWatchedButton(episodeNum: episodeNum, isWatched: isWatched)
      } else {
        episodeLockBadge(daysLeft: daysUntilAir(episode))
      }
    }
  }

  @ViewBuilder
  private func episodeWatchedButton(episodeNum: Int, isWatched: Bool) -> some View {
    Button {
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()

      if isWatched {
        _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          watchedEpisodes.remove(episodeNum)
        }
        if let season = viewModel.selectedSeason {
          UserLibraryManager.shared.toggleEpisodeWatched(
            showId: viewModel.title.stableNumericID,
            season: season.seasonNumber,
            episode: episodeNum
          )
        }
      } else if hasPreviousUnwatchedEpisodes(before: episodeNum) {
        pendingEpisodeNumber = episodeNum
        showMarkPreviousAlert = true
      } else {
        markSingleEpisode(episodeNum)
      }
    } label: {
      detailControlPill(
        systemImage: isWatched ? "checkmark" : "eye",
        title: isWatched ? "Watched" : "Watch"
      )
    }
    .padding(8)
  }

  @ViewBuilder
  private func episodeLockBadge(daysLeft: Int?) -> some View {
    VStack(spacing: 2) {
      Image(systemName: "lock.fill")
        .font(.system(size: 16))
      if let daysLeft {
        Text(daysLeft == 1 ? "1 day" : "\(daysLeft) days")
          .font(.system(size: 10, weight: .medium))
      }
    }
    .foregroundStyle(.white.opacity(0.8))
    .padding(8)
  }

  func isEpisodeReleased(_ episode: Title.Episode) -> Bool {
    guard let airDateStr = episode.airDate else { return true }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let airDate = formatter.date(from: airDateStr) else { return true }
    return airDate <= Date()
  }

  func daysUntilAir(_ episode: Title.Episode) -> Int? {
    guard let airDateStr = episode.airDate else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let airDate = formatter.date(from: airDateStr) else { return nil }
    let calendar = Calendar.current
    let fromDay = calendar.startOfDay(for: Date())
    let toDay = calendar.startOfDay(for: airDate)
    let days = calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
    return days >= 0 ? days : nil
  }

  func hasPreviousUnwatchedEpisodes(before episodeNum: Int) -> Bool {
    for ep in 1..<episodeNum {
      if !watchedEpisodes.contains(ep) {
        if let episode = viewModel.episodes.first(where: { $0.episodeNumber == ep }),
          isEpisodeReleased(episode)
        {
          return true
        }
      }
    }
    return false
  }

  func markEpisodeAndPrevious(_ episodeNum: Int) {
    guard let season = viewModel.selectedSeason else { return }
    let showId = viewModel.title.stableNumericID

    // Ensure the show exists in library for Watch Next
    UserLibraryManager.shared.ensureTVShowInLibrary(
      showId: showId,
      name: viewModel.title.name ?? "Unknown",
      posterPath: viewModel.title.posterPath
    )

    for ep in 1...episodeNum {
      if let episode = viewModel.episodes.first(where: { $0.episodeNumber == ep }),
        isEpisodeReleased(episode)
      {
        if !watchedEpisodes.contains(ep) {
          watchedEpisodes.insert(ep)
          UserLibraryManager.shared.markEpisodeWatched(
            showId: showId,
            season: season.seasonNumber,
            episode: ep,
            episodeName: episode.name,
            stillPath: episode.stillPath
          )
        }
      }
    }
  }

  func markSingleEpisode(_ episodeNum: Int) {
    guard let season = viewModel.selectedSeason else { return }
    let showId = viewModel.title.stableNumericID

    _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      watchedEpisodes.insert(episodeNum)
    }

    // Ensure the show exists in library for Watch Next
    UserLibraryManager.shared.ensureTVShowInLibrary(
      showId: showId,
      name: viewModel.title.name ?? "Unknown",
      posterPath: viewModel.title.posterPath
    )

    // Find the episode for its metadata
    let episode = viewModel.episodes.first(where: { $0.episodeNumber == episodeNum })

    // Mark episode watched with metadata
    UserLibraryManager.shared.markEpisodeWatched(
      showId: showId,
      season: season.seasonNumber,
      episode: episodeNum,
      episodeName: episode?.name,
      stillPath: episode?.stillPath
    )
  }

  func markAllEpisodesAllSeasons() {
    guard let seasons = viewModel.title.seasons else { return }
    let showId = viewModel.title.stableNumericID

    // Build seasons data for bulk marking
    let seasonsData = seasons.map {
      (seasonNumber: $0.seasonNumber, episodeCount: $0.episodeCount ?? 0)
    }

    // Mark all episodes across all seasons using the manager
    UserLibraryManager.shared.markAllSeasonsWatched(showId: showId, seasons: seasonsData)

    // Update current season's watched state in UI
    if viewModel.selectedSeason != nil {
      let episodeNums = viewModel.episodes.compactMap { $0.episodeNumber }
      watchedEpisodes = Set(
        episodeNums.filter { num in
          viewModel.episodes.first(where: { $0.episodeNumber == num }).map { isEpisodeReleased($0) }
            ?? false
        })
    }

    // Also mark the show as "watched" at title level
    if !isWatched {
      UserLibraryManager.shared.toggleWatched(for: viewModel.title)
      isWatched = true
    }
  }
}

extension NumberFormatter {
  static var currency: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    // Force US Locale for $ symbol
    formatter.locale = Locale(identifier: "en_US")
    return formatter
  }

  static func compactCurrency(value: Int) -> String {
    let doubleValue = Double(value)
    let million = 1_000_000.0
    let billion = 1_000_000_000.0

    // Force US Locale for $ symbol check or just prepend $
    if doubleValue >= billion {
      let formatted = String(format: "%.2f", doubleValue / billion)
      // Custom format: $X.XX Billion
      // Strip .00 if needed? User asked for up to 3 significant numbers (e.g. 1.25B)
      // Let's use NumberFormatter for significant digits?
      // Or simple string formatting:
      // Remove trailing zeros?
      let str = formatted.replacingOccurrences(of: ".00", with: "")
      return "$\(str) Billion"
    } else if doubleValue >= million {
      let formatted = String(format: "%.0f", doubleValue / million)
      return "$\(formatted) Million"
    } else {
      return currency.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    TitleDetailView(title: Title.previewTitles[0])
  } else {
    Text("Requires iOS 26.0+")
  }
}
