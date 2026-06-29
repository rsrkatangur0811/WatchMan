import SwiftUI

struct CompanyTitlesView: View {
  let company: ProductionCompany

  @State private var selectedMedia: CompanyMediaKind = .movie
  @State private var availableMediaKinds: [CompanyMediaKind] = []
  @State private var selectedSort: SortOption = .defaults
  @State private var titles: [Title] = []
  @State private var isLoading = true
  @State private var isFetchingMore = false
  @State private var hasMorePages = true
  @State private var currentPage = 1
  @State private var selectedTitle: Title?
  @State private var showTopBlur = false
  @State private var hasLoadedAvailability = false

  @Namespace private var heroTransition
  private let dataFetcher = DataFetcher()

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [.black, .white.opacity(0.12)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      ScrollView {
        LazyVStack(pinnedViews: [.sectionHeaders]) {
          Section {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: columns, spacing: 12) {
              ForEach(titles, id: \.stableDisplayID) { title in
                let sourceID = "company_\(company.id)_\(title.stableDisplayID)"
                PosterCard(
                  title: title,
                  width: nil,
                  height: nil,
                  namespace: heroTransition,
                  sourceID: sourceID,
                  showBorder: true
                )
                .aspectRatio(2 / 3, contentMode: .fit)
                .onTapGesture {
                  selectedTitle = title
                }
                .onAppear {
                  if title.stableDisplayID == titles.last?.stableDisplayID && hasMorePages && !isFetchingMore {
                    Task { await loadMoreContent() }
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
            HStack(spacing: 12) {
              if !availableMediaKinds.isEmpty {
                CompanyMediaFilterPillBar(
                  selectedMedia: $selectedMedia,
                  availableMediaKinds: availableMediaKinds,
                  showGlass: showTopBlur
                )
              }

            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.25), value: showTopBlur)
          }
        }
      }
      .scrollEdgeEffectSoftCompat(for: .top)
      .compatibleOnScrollGeometryChange(for: CGFloat.self) { geometry in
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
    .navigationTitle(company.name)
    .navigationBarTitleDisplayMode(.inline)
    .appNavigationBackButton()
    .navigationDestination(item: $selectedTitle) { title in
      TitleDetailView(title: title)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        sortMenu
      }
    }
    .task {
      if !hasLoadedAvailability {
        await loadAvailableMediaKinds()
      }
    }
    .onChange(of: selectedMedia) { _, _ in
      Task { await reloadContent() }
    }
    .onChange(of: selectedSort) { _, _ in
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.impactOccurred()
      Task { await reloadContent() }
    }
  }

  private var sortMenu: some View {
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

  private func loadAvailableMediaKinds() async {
    isLoading = true

    async let moviePreview = fetchCompanyTitles(for: .movie, page: 1)
    async let showPreview = fetchCompanyTitles(for: .tv, page: 1)

    let movies = await moviePreview
    let shows = await showPreview
    var kinds: [CompanyMediaKind] = []

    if !movies.isEmpty {
      kinds.append(.movie)
    }
    if !shows.isEmpty {
      kinds.append(.tv)
    }

    availableMediaKinds = kinds
    selectedMedia = kinds.first ?? .movie
    titles = selectedMedia == .movie ? movies : shows
    currentPage = titles.isEmpty ? 1 : 2
    hasMorePages = !titles.isEmpty
    hasLoadedAvailability = true
    isLoading = false
  }

  private func reloadContent() async {
    titles = []
    currentPage = 1
    hasMorePages = true
    isFetchingMore = false
    isLoading = true
    await loadMoreContent()
    isLoading = false
  }

  private func loadMoreContent() async {
    guard !isFetchingMore, hasMorePages else { return }
    isFetchingMore = true

    let fetched = await fetchCompanyTitles(for: selectedMedia, page: currentPage)
    if fetched.isEmpty {
      hasMorePages = false
    } else {
      let existingKeys = Set(titles.map(\.stableDisplayID))
      titles.append(contentsOf: fetched.filter { !existingKeys.contains($0.stableDisplayID) })
      currentPage += 1
    }

    isFetchingMore = false
  }

  private func fetchCompanyTitles(for mediaKind: CompanyMediaKind, page: Int) async -> [Title] {
    do {
      let fetched = try await dataFetcher.fetchTitles(
        for: mediaKind.apiMediaType,
        by: "discover",
        companies: String(company.id),
        voteCountMin: mediaKind == .movie ? 20 : 10,
        sortBy: selectedSort.apiValue(mediaType: mediaKind.apiMediaType),
        page: page
      )

      return fetched.filter { title in
        guard let posterPath = title.posterPath else { return false }
        return !posterPath.isEmpty && (title.voteAverage ?? 0) < 10
      }
    } catch {
      print("Failed company titles for \(company.name): \(error)")
      return []
    }
  }
}

enum CompanyMediaKind: String, CaseIterable, Identifiable {
  case movie = "Movies"
  case tv = "Shows"

  var id: String { rawValue }

  var apiMediaType: String {
    switch self {
    case .movie: return "movie"
    case .tv: return "tv"
    }
  }

  var icon: String {
    switch self {
    case .movie: return "film"
    case .tv: return "play.tv"
    }
  }
}

private struct CompanyMediaFilterPillBar: View {
  @Binding var selectedMedia: CompanyMediaKind
  let availableMediaKinds: [CompanyMediaKind]
  var showGlass: Bool = false
  @Namespace private var animation

  var body: some View {
    HStack(spacing: 0) {
      ForEach(availableMediaKinds) { mediaKind in
        Button {
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedMedia = mediaKind
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: mediaKind.icon)
              .font(.system(size: 16, weight: .medium))
            Text(mediaKind.rawValue)
              .font(.netflixSans(.medium, size: 15))
          }
          .foregroundStyle(selectedMedia == mediaKind ? .white : .white.opacity(0.7))
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background {
            if selectedMedia == mediaKind {
              Capsule()
                .fill(.clear)
                .glassedEffect(in: Capsule())
                .overlay {
                  Capsule()
                    .fill(Color.white.opacity(0.15))
                }
                .matchedGeometryEffect(id: "companyFilterPill", in: animation)
            }
          }
        }
        .buttonStyle(.plain)
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
              .fill(Color.black.opacity(showGlass ? 0.08 : 0.22))
            Capsule()
              .strokeBorder(Color.white.opacity(showGlass ? 0.24 : 0.18), lineWidth: 1)
          }
        }
    }
    .clipShape(Capsule())
    .animation(.easeInOut(duration: 0.2), value: showGlass)
  }
}
