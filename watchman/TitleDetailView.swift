import SafariServices
import SwiftUI

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

@available(iOS 26.0, *)
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

  init(title: Title) {
    self._viewModel = State(wrappedValue: DetailViewModel(title: title))
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
          .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      case .success:
        ZStack(alignment: .top) {
          ScrollView {
            VStack(alignment: .center, spacing: 20) {
              // MARK: - Header Section
              VStack(alignment: .leading, spacing: 0) {
                // 1. Backdrop Background
                if let path = randomBackdrop ?? viewModel.title.backdropPath
                  ?? viewModel.title.posterPath
                {
                  TMDBImage(path: path, size: .w1280) { image in
                    image
                      .resizable()
                      .scaledToFill()
                      .containerRelativeFrame(.horizontal)
                      .frame(height: 300)
                      .clipped()
                      .mask(
                        LinearGradient(
                          colors: [.black, .black, .black, .clear],
                          startPoint: .top,
                          endPoint: .bottom
                        )
                      )
                  } placeholder: {
                    Color.black
                      .containerRelativeFrame(.horizontal)
                      .aspectRatio(1.77, contentMode: .fit)
                  }
                }

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
                            .foregroundStyle(.gray)
                        }

                        // Show DIRECTED BY for movies, CREATED BY for TV shows
                        if viewModel.crew.first(where: { $0.job == "Director" }) != nil {
                          Text("•")
                            .foregroundStyle(.gray)
                          Text("DIRECTED BY")
                            .foregroundStyle(.gray)
                        } else if let creators = viewModel.title.createdBy, !creators.isEmpty {
                          // Use dedicated createdBy field for TV shows
                          Text("•")
                            .foregroundStyle(.gray)
                          Text("CREATED BY")
                            .foregroundStyle(.gray)
                        }
                      }
                      .font(.netflixSans(.bold, size: 12))

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
                          .font(.netflixSans(.medium, size: 14))
                          .foregroundStyle(.gray)
                      } else if let seasons = viewModel.title.numberOfSeasons, seasons > 0 {
                        Text("\(seasons) Season\(seasons == 1 ? "" : "s")")
                          .font(.netflixSans(.medium, size: 14))
                          .foregroundStyle(.gray)
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
                        .font(.netflixSans(.medium, size: 14))
                        .foregroundStyle(.gray)
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
                              lineWidth: 1.5
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
                    .background(
                      isInWatchlist
                        ? Color(red: 1.0, green: 0.18, blue: 0.39) : Color.white.opacity(0.1)
                    )
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
                      .background(
                        isWatched
                          ? Color(red: 0.0, green: 0.68, blue: 1.0) : Color.white.opacity(0.1)
                      )
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
                      }
                      .frame(maxWidth: .infinity)
                      .frame(height: 52)
                      .background(Color.white.opacity(0.05))
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
                        VStack {
                          if provider.providerName.contains("Hotstar")
                            || provider.providerName.contains("JioCinema")
                          {
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
                              showId: viewModel.title.id ?? 0,
                              season: season.seasonNumber
                            )
                            watchedEpisodes.removeAll()
                          } else {
                            // Mark all
                            let episodeNums = viewModel.episodes.compactMap { $0.episodeNumber }
                            UserLibraryManager.shared.markSeasonWatched(
                              showId: viewModel.title.id ?? 0,
                              season: season.seasonNumber,
                              episodeNumbers: episodeNums
                            )
                            watchedEpisodes = Set(episodeNums)
                          }
                        } label: {
                          Label(
                            allWatched ? "Unmark All Watched" : "Mark All Watched",
                            systemImage: allWatched ? "xmark.circle" : "checkmark.circle"
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
                      .padding(8)
                    }
                    .buttonStyle(.glass)
                  }
                  .padding(.horizontal, 24)

                  if !viewModel.episodes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                      HStack(spacing: 20) {
                        ForEach(viewModel.episodes) { episode in
                          let episodeNum = episode.episodeNumber ?? 0
                          let isWatched = watchedEpisodes.contains(episodeNum)
                          let isReleased = isEpisodeReleased(episode)
                          let daysLeft = daysUntilAir(episode)

                          VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                              // Episode image
                              AsyncImage(url: episode.stillURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
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
                                    lineWidth: isWatched ? 2 : 1)
                              )
                              // Gray overlay for unreleased episodes
                              .overlay {
                                if !isReleased {
                                  RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.6))
                                }
                              }

                              // Eye/Checkmark button or Lock for unreleased
                              if isReleased {
                                Button {
                                  let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                  impactFeedback.impactOccurred()

                                  if isWatched {
                                    // Unmark episode
                                    _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7))
                                    {
                                      watchedEpisodes.remove(episodeNum)
                                    }
                                    if let season = viewModel.selectedSeason {
                                      UserLibraryManager.shared.toggleEpisodeWatched(
                                        showId: viewModel.title.id ?? 0,
                                        season: season.seasonNumber,
                                        episode: episodeNum
                                      )
                                    }
                                  } else {
                                    // Check for previous unwatched episodes
                                    if hasPreviousUnwatchedEpisodes(before: episodeNum) {
                                      pendingEpisodeNumber = episodeNum
                                      showMarkPreviousAlert = true
                                    } else {
                                      markSingleEpisode(episodeNum)
                                    }
                                  }
                                } label: {
                                  Image(
                                    systemName: isWatched
                                      ? "checkmark.circle.fill" : "eye.circle.fill"
                                  )
                                  .font(.system(size: 28))
                                  .foregroundStyle(isWatched ? .green : .white)
                                  .background(Circle().fill(.black.opacity(0.5)).padding(2))
                                }
                                .padding(8)
                              } else {
                                // Unreleased - show lock with countdown
                                VStack(spacing: 2) {
                                  Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                  if let days = daysLeft {
                                    Text(days == 1 ? "1 day" : "\(days) days")
                                      .font(.system(size: 10, weight: .medium))
                                  }
                                }
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(8)
                              }
                            }

                            Text("\(episodeNum). \(episode.name)")
                              .font(.netflixSans(.bold, size: 15))
                              .foregroundStyle(isWatched ? .green : (isReleased ? .white : .gray))
                              .lineLimit(1)

                            Text(episode.overview ?? "No description available.")
                              .font(.netflixSans(.medium, size: 12))
                              .foregroundStyle(.gray)
                              .lineLimit(2)
                              .multilineTextAlignment(.leading)
                          }
                          .frame(width: 220)
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
                    LazyHStack(alignment: .top, spacing: 12) {
                      // Directors first
                      ForEach(viewModel.crew.filter { $0.job == "Director" }) { crew in
                        NavigationLink(
                          destination: PersonDetailView(
                            personId: crew.id, name: crew.name, profileURL: crew.profileURL)
                        ) {
                          VStack(spacing: 6) {
                            AsyncImage(url: crew.profileURL) { image in
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
                              Text(crew.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 80)
                              
                              Text("Director")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .frame(width: 80)
                            }
                          }
                        }
                        .buttonStyle(.plain)
                      }

                      // Then cast members
                      ForEach(Array(viewModel.cast.prefix(20).enumerated()), id: \.offset) { _, cast in
                        NavigationLink(
                          destination: PersonDetailView(
                            personId: cast.id, name: cast.name, profileURL: cast.profileURL)
                        ) {
                          VStack(spacing: 6) {
                            AsyncImage(url: cast.profileURL) { image in
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
                              Text(cast.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 80)
                              
                              if let character = cast.character, !character.isEmpty {
                                Text(character)
                                  .font(.caption2)
                                  .foregroundStyle(.white.opacity(0.7))
                                  .lineLimit(1)
                                  .frame(width: 80)
                              }
                            }
                          }
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
                if !viewModel.reviews.isEmpty {
                  VStack(alignment: .leading) {
                    Text("Reviews")
                      .font(.netflixSans(.bold, size: 20)).foregroundStyle(.white).padding(
                        .horizontal, 24)
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

                // MARK: - This Series (Above Recommended)
                if !viewModel.collectionTitles.isEmpty {
                  VStack(alignment: .leading) {
                    Text(viewModel.title.belongsToCollection?.name ?? "This Series")
                      .font(.netflixSans(.bold, size: 20))
                      .foregroundStyle(.white)
                      .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                      LazyHStack(spacing: 15) {
                        ForEach(viewModel.collectionTitles) { title in
                          NavigationLink(destination: TitleDetailView(title: title)) {
                            SmallTitleCard(title: title)
                          }
                        }
                      }
                      .padding(.horizontal, 24)
                    }
                  }
                }

                if !viewModel.recommendations.isEmpty {
                  VStack(alignment: .leading) {
                    Text("Recommended").font(.netflixSans(.bold, size: 20)).foregroundStyle(.white)
                      .padding(
                        .horizontal, 24)
                    ScrollView(.horizontal, showsIndicators: false) {
                      LazyHStack(spacing: 15) {
                        ForEach(viewModel.recommendations) { title in
                          NavigationLink(destination: TitleDetailView(title: title)) {
                            SmallTitleCard(title: title)
                          }
                        }
                      }
                      .padding(.horizontal, 24)
                    }
                  }
                }

                // MARK: - More from Director/Creator (Below Recommended)
                if !viewModel.directorCredits.isEmpty, let name = viewModel.directorName {
                  VStack(alignment: .leading) {
                    Text("More from \(name)")
                      .font(.netflixSans(.bold, size: 20))
                      .foregroundStyle(.white)
                      .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                      LazyHStack(spacing: 15) {
                        ForEach(viewModel.directorCredits) { title in
                          NavigationLink(destination: TitleDetailView(title: title)) {
                            SmallTitleCard(title: title)
                          }
                        }
                      }
                      .padding(.horizontal, 24)
                    }
                  }
                }
              }

              Spacer(minLength: 50)
            }
            .background(
              GeometryReader { geo in
                Color.clear
                  .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("scroll")).minY
                  )
              }
            )
          }
          .coordinateSpace(name: "scroll")
          .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let scrollDown = value < -10
            let progress = max(0, min(1, -value / 80))
            showTopBlur = scrollDown
            scrollProgress = progress
          }
          .ignoresSafeArea(edges: .top)
          .scrollEdgeEffectHidden(true)

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
                .interactiveSpring(response: 0.25, dampingFraction: 0.85), value: scrollProgress
              )
              .allowsHitTesting(false)
              .ignoresSafeArea(edges: .top)
          }
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
      blurredBackground
    }
    .overlay(alignment: .bottom) {
      ratingPillOverlay
        .padding(.bottom, 10)
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
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
      // Initialize library manager with model context
      UserLibraryManager.shared.setModelContext(modelContext)

      // Load existing library state
      let titleId = viewModel.title.id ?? 0
      let mediaType = viewModel.title.name != nil ? "tv" : "movie"
      isInWatchlist = UserLibraryManager.shared.isInWatchlist(
        titleId: titleId, mediaType: mediaType)
      isWatched = UserLibraryManager.shared.isWatched(titleId: titleId, mediaType: mediaType)
      userRating = UserLibraryManager.shared.getRating(titleId: titleId, mediaType: mediaType)

      await viewModel.loadAllData()
      if let path = viewModel.title.backdropPath ?? viewModel.title.posterPath {
        updateColor(for: path)
      }
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
          showId: viewModel.title.id ?? 0,
          season: season.seasonNumber
        )
        watchedEpisodes = Set(watched)
      } else {
        watchedEpisodes.removeAll()
      }
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
    let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    guard let url else { return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, let uiImage = UIImage(data: data) else { return }
      if let avgColor = uiImage.dominantBrightColor {
        DispatchQueue.main.async {
          withAnimation {
            // Darken the color a bit for background suitability
            self.currentBackdropColor = Color(uiColor: avgColor).opacity(0.3)
          }
        }
      }
    }.resume()
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
@available(iOS 26.0, *)
extension TitleDetailView {
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
    let days = Calendar.current.dateComponents([.day], from: Date(), to: airDate).day ?? 0
    return days > 0 ? days : nil
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
    let showId = viewModel.title.id ?? 0

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
    let showId = viewModel.title.id ?? 0

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
    let showId = viewModel.title.id ?? 0

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
