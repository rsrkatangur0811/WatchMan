import SwiftUI

@available(iOS 26.0, *)
struct PersonDetailView: View {
  let personId: Int
  let name: String
  let profileURL: URL?

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

  enum MediaTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case movies = "Movies"
    case shows = "Shows"
    var id: String { rawValue }
  }

  @State private var selectedFilter: MediaTypeFilter = .all
  @State private var selectedSort: SortOption = .defaults

  var sortedCredits: [Title] {
    let filtered: [Title]
    switch selectedFilter {
    case .all:
      filtered = credits.filter { $0.posterPath != nil && !$0.posterPath!.isEmpty }
    case .movies:
      filtered = credits.filter {
        $0.mediaType == "movie" && $0.posterPath != nil && !$0.posterPath!.isEmpty
      }
    case .shows:
      filtered = credits.filter {
        $0.mediaType == "tv" && $0.posterPath != nil && !$0.posterPath!.isEmpty
      }
    }

    switch selectedSort {
    case .defaults, .popularity:
      return filtered.sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) } // Default to popularity as well for consistency
    case .name:
      return filtered.sorted { ($0.title ?? $0.name ?? "") < ($1.title ?? $1.name ?? "") }
    case .releaseDate:
      return filtered.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
    case .rating:
      return filtered.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
    }
  }

  @State private var credits: [Title] = []
  @State private var biography: String?
  @State private var isBioExpanded = false
  @State private var isLoading = true
  @State private var errorMessage: String?
  @State private var currentProfileColor: Color = .black
  @State private var showTopBlur = false

  private let dataFetcher = DataFetcher()

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // MARK: - Header
        VStack(spacing: 15) {
          Text(name)
            .font(.netflixSans(.bold, size: 32))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

          AsyncImage(url: profileURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
          } placeholder: {
            ZStack {
              Color.gray.opacity(0.3)
              Image(systemName: "person.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.5))
            }
          }
          .frame(width: 150, height: 225)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 2)
          )
          .shadow(radius: 10)
        }

        // MARK: - Biography
        if let bio = biography, !bio.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Biography")
              .font(.netflixSans(.bold, size: 20))
              .foregroundStyle(.white)

            Text(bio)
              .font(.netflixSans(.medium, size: 16))
              .foregroundStyle(.white.opacity(0.8))
              .lineLimit(isBioExpanded ? nil : 4)
              .fixedSize(horizontal: false, vertical: true)

            if bio.count > 240 {
              Button(action: {
                withAnimation { isBioExpanded.toggle() }
              }) {
                Text(isBioExpanded ? "Read Less" : "Read More")
                  .font(.netflixSans(.bold, size: 14))
                  .foregroundStyle(.white)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
        }

        // MARK: - Known For / Credits
        if isLoading {
          ProgressView()
            .padding(.top, 50)
            .tint(.white)
        } else if let error = errorMessage {
          VStack {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundStyle(.yellow)
            Text("Failed to load credits")
            Text(error).font(.caption).foregroundStyle(.gray)
          }
          .padding(.top, 50)
        } else if credits.isEmpty {
          Text("No credits found.")
            .foregroundStyle(.gray)
            .padding(.top, 20)
        } else {
          LazyVStack(pinnedViews: [.sectionHeaders]) {
            Section {
              LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                spacing: 16
              ) {
                ForEach(sortedCredits) { title in
                  NavigationLink(destination: TitleDetailView(title: title)) {
                    RepairablePosterCard(title: title)
                      .aspectRatio(2 / 3, contentMode: .fit)
                  }
                }
              }
              .padding(.horizontal)
            } header: {
              // Sticky Filter Bar with Sort Button
              HStack(spacing: 12) {
                PersonFilterPillBar(selectedFilter: $selectedFilter, showGlass: showTopBlur)

                // Sort Button (only visible when not scrolled)
                if !showTopBlur {
                  Menu {
                    Picker("Sort By", selection: $selectedSort) {
                      ForEach(SortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon).tag(option)
                      }
                    }
                  } label: {
                    HStack(spacing: 6) {
                      if selectedSort != .defaults {
                          Image(systemName: selectedSort.icon)
                            .font(.system(size: 14, weight: .medium))
                      } else {
                          Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                      }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                      Capsule()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                          Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    )
                  }
                  .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
              }
              .padding(.horizontal)
              .padding(.vertical, 10)
              .background(Color.black.opacity(0.001))  // Ensures touch area
              .animation(.easeInOut(duration: 0.25), value: showTopBlur)
            }
          }
        }
      }
      .padding(.bottom, 30)
    }
    .onScrollGeometryChange(for: CGFloat.self) { geometry in
      geometry.contentOffset.y + geometry.contentInsets.top
    } action: { _, newValue in
      withAnimation {
        showTopBlur = newValue > 0
      }
    }
    .background {
      LinearGradient(
        gradient: Gradient(colors: [currentProfileColor, .black]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      // Sort button moves to toolbar when scrolled
      ToolbarItem(placement: .topBarTrailing) {
        if showTopBlur {
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
          }
          .transition(.opacity)
        }
      }
    }
    .animation(.easeInOut(duration: 0.25), value: showTopBlur)
    .task {
      await loadCredits()
      if let profileURL {
        updateColor(for: profileURL)
      }
    }
  }

  private func loadCredits() async {
    do {
      let fetchedCredits = try await dataFetcher.fetchPersonCredits(personId: personId)
      credits = fetchedCredits.filter { ($0.voteAverage ?? 0) < 10.0 }

      // Fetch details in parallel or sequentially
      let personDetails = try await dataFetcher.fetchPersonDetails(personId: personId)
      biography = personDetails.biography

      isLoading = false
    } catch {
      print("Failed to load person data: \(error)")
      isLoading = false
      errorMessage = error.localizedDescription
    }
  }

  private func updateColor(for url: URL) {
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, let uiImage = UIImage(data: data) else { return }
      if let dominantColor = uiImage.dominantBrightColor {
        DispatchQueue.main.async {
          withAnimation {
            // Darken the color a bit for background suitability
            self.currentProfileColor = Color(uiColor: dominantColor).opacity(0.3)
          }
        }
      }
    }.resume()
  }
}

@available(iOS 26.0, *)
struct RepairablePosterCard: View {
  let title: Title
  @State private var displayTitle: Title

  init(title: Title) {
    self.title = title
    _displayTitle = State(initialValue: title)
  }

  var body: some View {
    PosterCard(
      title: displayTitle, width: nil, height: nil,
      onFailure: {
        Task {
          await repairTitle()
        }
      })
  }

  private func repairTitle() async {
    // Prevent infinite loop if we already have a valid poster but logic fails elsewhere
    // But mostly we just want to try fetching details once.
    guard let id = title.id else { return }
    // Infer media type if missing. Person credits usually have specific fields.
    let mediaType = title.mediaType ?? (title.name != nil ? "tv" : "movie")

    do {
      let fetcher = DataFetcher()
      let freshDetails = try await fetcher.fetchTitleDetails(for: mediaType, id: id)

      // If we got a new poster path, update!
      if let newPath = freshDetails.posterPath, newPath != displayTitle.posterPath {
        await MainActor.run {
          self.displayTitle = freshDetails
        }
      }
    } catch {
      print("Failed to repair title \(title.title ?? title.name ?? ""): \(error)")
    }
  }
}

// MARK: - Custom Person Filter Pill Bar
@available(iOS 26.0, *)
struct PersonFilterPillBar: View {
  @Binding var selectedFilter: PersonDetailView.MediaTypeFilter
  var showGlass: Bool = false
  @Namespace private var animation

  var body: some View {
    HStack(spacing: 0) {
      ForEach(PersonDetailView.MediaTypeFilter.allCases) { filter in
        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedFilter = filter
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: iconFor(filter))
              .font(.system(size: 14, weight: .medium))
            Text(filter.rawValue)
              .font(.netflixSans(.medium, size: 14))
          }
          .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.7))
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background {
            if selectedFilter == filter {
              Capsule()
                .fill(Color.white.opacity(0.15))
                .matchedGeometryEffect(id: "personFilterPill", in: animation)
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background {
      if showGlass {
        Capsule()
          .fill(.clear)
          .glassEffect(.regular, in: .capsule)
      } else {
        Capsule()
          .fill(Color.black.opacity(0.3))
          .overlay(
            Capsule()
              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
          )
      }
    }
    .animation(.easeInOut(duration: 0.2), value: showGlass)
  }

  private func iconFor(_ filter: PersonDetailView.MediaTypeFilter) -> String {
    switch filter {
    case .all: return "play.rectangle"
    case .movies: return "film"
    case .shows: return "play.tv"
    }
  }
}
