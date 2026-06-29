import SwiftUI

struct TasteProfileView: View {
  let items: [UserLibraryItem]

  @State private var profile = TasteProfile.empty
  @State private var selectedPoster: TasteProfilePoster?

  private var signature: String {
    items
      .map { "\($0.uniqueId)-\($0.modifiedAt.timeIntervalSince1970)-\($0.flickRankOrder ?? -1)" }
      .joined(separator: "|")
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 26) {
          header

          if profile.totalTitles == 0 {
            emptyState
          } else {
            topShelfHero
            metricStrip
            rankingNotice
            if profile.hasFlickRank {
              posterRail("Flick Ranking", posters: profile.topShelfPosters)
            }
            ratingTiers
            posterRail("Highest Rated", posters: profile.highestRatedPosters)
            rankedSection("Genres", rows: profile.topGenres, icon: "square.grid.2x2")
            rankedSection("Decades", rows: profile.topDecades, icon: "calendar")
            ratingDistribution
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 34)
      }
    }
    .navigationTitle("Taste Profile")
    .navigationBarTitleDisplayMode(.inline)
    .appNavigationBackButton()
    .task(id: signature) {
      await buildProfile()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Taste Profile")
        .font(.netflixSans(.bold, size: 34))
        .foregroundStyle(.white)

      Text("A visual map of your watched and rated history.")
        .font(.netflixSans(.medium, size: 15))
        .foregroundStyle(.gray)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      Image(systemName: "chart.bar.xaxis")
        .font(.system(size: 48, weight: .light))
        .foregroundStyle(.gray)
      Text("No profile yet")
        .font(.netflixSans(.bold, size: 20))
        .foregroundStyle(.white)
      Text("Import or mark a few titles watched to build your profile.")
        .font(.netflixSans(.medium, size: 14))
        .foregroundStyle(.gray)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 80)
  }

  private var topShelfHero: some View {
    let poster = selectedPoster ?? profile.topShelfPosters.first
    return Group {
      if let poster {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .bottom, spacing: 16) {
            posterImage(poster, width: 128, height: 192)
              .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 8) {
              Text(profile.hasFlickRank ? "Flick Leader" : "Top Rated")
                .font(.netflixSans(.medium, size: 13))
                .foregroundStyle(.gray)
              Text(poster.title)
                .font(.netflixSans(.bold, size: 26))
                .foregroundStyle(.white)
                .lineLimit(4)
              if let rating = poster.rating {
                Label(String(format: "%.1f / 10", rating), systemImage: "star.fill")
                  .font(.netflixSans(.bold, size: 14))
                  .foregroundStyle(.white.opacity(0.88))
              }
              Text(poster.rankLabel)
                .font(.netflixSans(.medium, size: 13))
                .foregroundStyle(.gray)
            }
            Spacer(minLength: 0)
          }

          Text(profile.summary)
            .font(.netflixSans(.medium, size: 15))
            .foregroundStyle(.white.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background {
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .trailing) {
              posterImage(poster, width: 190, height: 285)
                .opacity(0.10)
                .blur(radius: 12)
                .offset(x: 42)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }

  private var metricStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 10) {
        metric("Watched", "\(profile.watchedTitles)", "checkmark.circle")
        metric("Rated", "\(profile.ratedTitles)", "star")
        metric("Average", profile.averageRatingText, "chart.line.uptrend.xyaxis")
        metric("10s", "\(profile.perfectRatings)", "crown")
        metric("Imported", "\(profile.letterboxdTitles)", "arrow.down.circle")
      }
      .scrollTargetLayoutCompat()
    }
    .scrollTargetBehaviorCompat()
  }

  @ViewBuilder
  private var rankingNotice: some View {
    if !profile.hasFlickRank {
      HStack(spacing: 10) {
        Image(systemName: "info.circle")
          .foregroundStyle(.gray)
        Text("Re-sync Letterboxd to populate Flick-style ordering from your public ratings-sorted Letterboxd page.")
          .font(.netflixSans(.medium, size: 13))
          .foregroundStyle(.gray)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding()
      .background(Color.white.opacity(0.07))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var ratingTiers: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Rating Tiers", icon: "rectangle.3.group")

      VStack(spacing: 14) {
        ForEach(profile.ratingTiers) { tier in
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(tier.title)
                .font(.netflixSans(.bold, size: 17))
                .foregroundStyle(.white)
              Spacer()
              Text("\(tier.posters.count)")
                .font(.netflixSans(.bold, size: 13))
                .foregroundStyle(.gray)
            }

            ScrollView(.horizontal, showsIndicators: false) {
              LazyHStack(spacing: -10) {
                ForEach(tier.posters.prefix(14)) { poster in
                  Button {
                    withAnimation(.snappy) {
                      selectedPoster = poster
                    }
                  } label: {
                    posterImage(poster, width: 70, height: 105)
                      .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                  }
                  .buttonStyle(.plain)
                  .scrollTransition(.animated(.smooth)) { content, phase in
                    content
                      .opacity(phase.isIdentity ? 1 : 0.5)
                      .scaleEffect(phase.isIdentity ? 1 : 0.9)
                  }
                }
              }
              .padding(.horizontal, 2)
            }
          }
          .padding()
          .background(Color.white.opacity(0.07))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
    }
  }

  private var ratingDistribution: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Rating Spread", icon: "chart.bar")

      VStack(spacing: 12) {
        ForEach(profile.ratingBuckets) { bucket in
          HStack(spacing: 10) {
            Text(bucket.label)
              .font(.netflixSans(.medium, size: 13))
              .foregroundStyle(.gray)
              .frame(width: 54, alignment: .leading)

            GeometryReader { proxy in
              Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(alignment: .leading) {
                  Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(bucket.count == 0 ? 0 : 4, proxy.size.width * bucket.fraction))
                }
            }
            .frame(height: 10)

            Text("\(bucket.count)")
              .font(.netflixSans(.bold, size: 13))
              .foregroundStyle(.white)
              .frame(width: 30, alignment: .trailing)
          }
        }
      }
      .padding()
      .background(Color.white.opacity(0.07))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text(value)
        .font(.netflixSans(.bold, size: 24))
        .foregroundStyle(.white)
      Text(title)
        .font(.netflixSans(.medium, size: 12))
        .foregroundStyle(.gray)
    }
    .padding()
    .frame(width: 126, alignment: .leading)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .scrollTransition(.animated(.smooth)) { content, phase in
      content
        .scaleEffect(phase.isIdentity ? 1 : 0.94)
        .opacity(phase.isIdentity ? 1 : 0.66)
    }
  }

  @ViewBuilder
  private func posterRail(_ title: String, posters: [TasteProfilePoster]) -> some View {
    if !posters.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle(title, icon: "rectangle.stack")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: 12) {
            ForEach(posters) { poster in
              Button {
                withAnimation(.snappy) {
                  selectedPoster = poster
                }
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  posterImage(poster, width: 108, height: 162)
                  Text(poster.title)
                    .font(.netflixSans(.medium, size: 12))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .frame(width: 108, alignment: .leading)
                  Text(poster.compactLabel)
                    .font(.netflixSans(.bold, size: 12))
                    .foregroundStyle(.gray)
                }
              }
              .buttonStyle(.plain)
              .scrollTransition(.animated(.smooth)) { content, phase in
                content
                  .opacity(phase.isIdentity ? 1 : 0.45)
                  .scaleEffect(phase.isIdentity ? 1 : 0.88)
                  .rotation3DEffect(.degrees(phase.value * -7), axis: (x: 0, y: 1, z: 0))
              }
            }
          }
          .scrollTargetLayoutCompat()
        }
        .scrollTargetBehaviorCompat()
      }
    }
  }

  @ViewBuilder
  private func rankedSection(_ title: String, rows: [TasteRankedValue], icon: String) -> some View {
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle(title, icon: icon)

        VStack(spacing: 10) {
          ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            HStack(spacing: 12) {
              Text("\(index + 1)")
                .font(.netflixSans(.bold, size: 14))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white))

              VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                  .font(.netflixSans(.bold, size: 15))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                Text(row.detail)
                  .font(.netflixSans(.medium, size: 12))
                  .foregroundStyle(.gray)
              }

              Spacer()

              GeometryReader { proxy in
                Capsule()
                  .fill(Color.white.opacity(0.12))
                  .overlay(alignment: .leading) {
                    Capsule()
                      .fill(Color.white.opacity(0.78))
                      .frame(width: proxy.size.width * row.fraction)
                  }
              }
              .frame(width: 74, height: 8)
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scrollTransition(.animated(.smooth)) { content, phase in
              content
                .opacity(phase.isIdentity ? 1 : 0.65)
                .offset(x: phase.isIdentity ? 0 : phase.value * 18)
            }
          }
        }
      }
    }
  }

  private func sectionTitle(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .font(.netflixSans(.bold, size: 20))
      .foregroundStyle(.white)
  }

  private func posterImage(_ poster: TasteProfilePoster, width: CGFloat, height: CGFloat) -> some View {
    TMDBImage(path: poster.posterPath, size: .w500) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      Rectangle()
        .fill(Color.white.opacity(0.1))
        .overlay {
          Image(systemName: poster.mediaType == "tv" ? "play.tv" : "film")
            .foregroundStyle(.gray)
        }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    .clipped()
  }

  private func buildProfile() async {
    let snapshots = items.map(TasteProfileSnapshot.init)
    let builder = TasteProfileBuilder()
    let localProfile = builder.buildLocal(from: snapshots)
    profile = localProfile
    selectedPoster = localProfile.topShelfPosters.first

    let enriched = await builder.enrich(localProfile, from: snapshots)
    withAnimation(.smooth(duration: 0.25)) {
      profile = enriched
    }
  }
}

private struct TasteProfileSnapshot: Sendable {
  let titleId: Int
  let mediaType: String
  let titleName: String
  let posterPath: String?
  let isWatched: Bool
  let userRating: Double?
  let letterboxdRating: Double?
  let flickRankOrder: Int?
  let importedSource: String?
  let modifiedAt: Date

  init(item: UserLibraryItem) {
    titleId = item.titleId
    mediaType = item.mediaType
    titleName = item.titleName
    posterPath = item.posterPath
    isWatched = item.isWatched
    userRating = item.userRating
    letterboxdRating = item.letterboxdRating
    flickRankOrder = item.flickRankOrder
    importedSource = item.importedSource
    modifiedAt = item.modifiedAt
  }

  var rating: Double? {
    userRating ?? letterboxdRating
  }

  var poster: TasteProfilePoster {
    TasteProfilePoster(
      titleId: titleId,
      mediaType: mediaType,
      title: titleName,
      posterPath: posterPath,
      rating: rating,
      flickRank: flickRankOrder,
      modifiedAt: modifiedAt
    )
  }
}

private struct TasteProfilePoster: Identifiable, Hashable {
  let titleId: Int
  let mediaType: String
  let title: String
  let posterPath: String?
  let rating: Double?
  let flickRank: Int?
  let modifiedAt: Date

  var id: String { "\(mediaType)_\(titleId)" }

  var posterURL: URL? {
    guard let posterPath, !posterPath.isEmpty else { return nil }
    if posterPath.hasPrefix("http") {
      return URL(string: posterPath)
    }
    let cleanPath = posterPath.hasPrefix("/") ? posterPath : "/\(posterPath)"
    return URL(string: "https://image.tmdb.org/t/p/w500\(cleanPath)")
  }

  var rankLabel: String {
    if let flickRank {
      return "Flick rank #\(flickRank)"
    }
    return "Rating tier"
  }

  var compactLabel: String {
    if let flickRank {
      return "#\(flickRank)"
    }
    if let rating {
      return String(format: "%.1f", rating)
    }
    return "Watched"
  }
}

private struct TasteRankedValue: Identifiable, Equatable {
  var id: String { name }
  let name: String
  let detail: String
  let fraction: Double
}

private struct TasteRatingBucket: Identifiable, Equatable {
  var id: String { label }
  let label: String
  let count: Int
  let fraction: Double
}

private struct TasteRatingTier: Identifiable, Equatable {
  var id: String { title }
  let title: String
  let posters: [TasteProfilePoster]
}

private struct TasteProfile: Equatable {
  var totalTitles: Int
  var watchedTitles: Int
  var ratedTitles: Int
  var perfectRatings: Int
  var letterboxdTitles: Int
  var averageRating: Double?
  var hasFlickRank: Bool
  var topShelfPosters: [TasteProfilePoster]
  var highestRatedPosters: [TasteProfilePoster]
  var ratingTiers: [TasteRatingTier]
  var topGenres: [TasteRankedValue]
  var topDecades: [TasteRankedValue]
  var ratingBuckets: [TasteRatingBucket]
  var analysisNote: String

  var averageRatingText: String {
    guard let averageRating else { return "-" }
    return String(format: "%.1f", averageRating)
  }

  var summary: String {
    let genre = topGenres.first?.name ?? "your watched titles"
    let decade = topDecades.first?.name ?? "multiple eras"
    if hasFlickRank {
      return "Flick rank data drives the top shelf. Beyond that, \(genre) and \(decade) are the strongest visible patterns."
    }
    return "This profile respects your rating tiers. \(genre) and \(decade) are the strongest visible patterns."
  }

  static let empty = TasteProfile(
    totalTitles: 0,
    watchedTitles: 0,
    ratedTitles: 0,
    perfectRatings: 0,
    letterboxdTitles: 0,
    averageRating: nil,
    hasFlickRank: false,
    topShelfPosters: [],
    highestRatedPosters: [],
    ratingTiers: [],
    topGenres: [],
    topDecades: [],
    ratingBuckets: [],
    analysisNote: ""
  )
}

private struct TasteProfileBuilder {
  private let dataFetcher = DataFetcher()
  private let detailBatchSize = 8

  func buildLocal(from snapshots: [TasteProfileSnapshot]) -> TasteProfile {
    let relevant = snapshots.filter { $0.isWatched || $0.rating != nil }
    guard !relevant.isEmpty else { return .empty }

    let ratings = relevant.compactMap(\.rating)
    let average = ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count)
    let posters = relevant.map(\.poster).filter { $0.posterURL != nil }
    let rankedPosters = flickRankedPosters(from: posters)
    let highestRated = highestRatedPosters(from: posters)

    return TasteProfile(
      totalTitles: snapshots.count,
      watchedTitles: snapshots.filter(\.isWatched).count,
      ratedTitles: ratings.count,
      perfectRatings: ratings.filter { $0 >= 9.95 }.count,
      letterboxdTitles: snapshots.filter { $0.importedSource == "letterboxd" }.count,
      averageRating: average,
      hasFlickRank: !rankedPosters.isEmpty,
      topShelfPosters: Array((rankedPosters.isEmpty ? highestRated : rankedPosters).prefix(28)),
      highestRatedPosters: Array(highestRated.prefix(24)),
      ratingTiers: ratingTiers(from: posters),
      topGenres: [],
      topDecades: [],
      ratingBuckets: ratingBuckets(from: ratings),
      analysisNote: rankedPosters.isEmpty
        ? "Rating tiers are faithful to imported ratings. Re-sync Letterboxd to populate Flick-style order."
        : "Letterboxd rating-sorted order is being used for the top shelf."
    )
  }

  func enrich(_ base: TasteProfile, from snapshots: [TasteProfileSnapshot]) async -> TasteProfile {
    let relevant = snapshots.filter { $0.isWatched || $0.rating != nil }
    guard !relevant.isEmpty else { return base }

    let details = await fetchDetails(for: relevant)
    var enriched = base
    enriched.topGenres = rankedGenres(from: details)
    enriched.topDecades = rankedDecades(from: details)
    enriched.analysisNote = "\(base.analysisNote) Genres and decades cover \(details.count) of \(relevant.count) watched/rated titles."
    return enriched
  }

  private func flickRankedPosters(from posters: [TasteProfilePoster]) -> [TasteProfilePoster] {
    posters
      .filter { $0.flickRank != nil }
      .sorted { ($0.flickRank ?? Int.max) < ($1.flickRank ?? Int.max) }
  }

  private func highestRatedPosters(from posters: [TasteProfilePoster]) -> [TasteProfilePoster] {
    posters.sorted {
      let leftRating = $0.rating ?? 0
      let rightRating = $1.rating ?? 0
      if abs(leftRating - rightRating) >= 0.01 {
        return leftRating > rightRating
      }
      if $0.flickRank != nil || $1.flickRank != nil {
        return ($0.flickRank ?? Int.max) < ($1.flickRank ?? Int.max)
      }
      return $0.modifiedAt > $1.modifiedAt
    }
  }

  private func ratingTiers(from posters: [TasteProfilePoster]) -> [TasteRatingTier] {
    let tiers: [(String, (TasteProfilePoster) -> Bool)] = [
      ("Perfect 10s", { ($0.rating ?? -1) >= 9.95 }),
      ("9s", { ($0.rating ?? -1) >= 9 && ($0.rating ?? -1) < 9.95 }),
      ("8s", { ($0.rating ?? -1) >= 8 && ($0.rating ?? -1) < 9 }),
      ("7s", { ($0.rating ?? -1) >= 7 && ($0.rating ?? -1) < 8 }),
      ("Watched", { $0.rating == nil }),
    ]

    return tiers.compactMap { title, contains in
      let tierPosters = highestRatedPosters(from: posters.filter(contains))
      guard !tierPosters.isEmpty else { return nil }
      return TasteRatingTier(title: title, posters: tierPosters)
    }
  }

  private func fetchDetails(for items: [TasteProfileSnapshot]) async -> [TitleDTO] {
    var allDetails: [TitleDTO] = []

    for batchStart in stride(from: 0, to: items.count, by: detailBatchSize) {
      let batchEnd = min(batchStart + detailBatchSize, items.count)
      let batch = Array(items[batchStart..<batchEnd])

      let details = await withTaskGroup(of: TitleDTO?.self) { group in
        for item in batch {
          group.addTask {
            try? await dataFetcher.fetchTitleDetailsDTO(for: item.mediaType, id: item.titleId)
          }
        }

        var results: [TitleDTO] = []
        for await result in group {
          if let result {
            results.append(result)
          }
        }
        return results
      }

      allDetails.append(contentsOf: details)
    }

    return allDetails
  }

  private func rankedGenres(from details: [TitleDTO]) -> [TasteRankedValue] {
    var counts: [String: Int] = [:]
    for detail in details {
      for genre in detail.genres ?? [] {
        counts[genre.name, default: 0] += 1
      }
    }
    return rankedValues(counts, suffix: "titles")
  }

  private func rankedDecades(from details: [TitleDTO]) -> [TasteRankedValue] {
    var counts: [String: Int] = [:]
    for detail in details {
      guard let date = detail.releaseDate ?? detail.firstAirDate,
        let year = Int(date.prefix(4))
      else {
        continue
      }
      counts["\((year / 10) * 10)s", default: 0] += 1
    }
    return rankedValues(counts, suffix: "titles")
  }

  private func rankedValues(_ counts: [String: Int], suffix: String) -> [TasteRankedValue] {
    let maxCount = max(1, counts.values.max() ?? 1)
    return counts
      .sorted {
        if $0.value == $1.value {
          return $0.key < $1.key
        }
        return $0.value > $1.value
      }
      .prefix(8)
      .map {
        TasteRankedValue(
          name: $0.key,
          detail: "\($0.value) \(suffix)",
          fraction: Double($0.value) / Double(maxCount)
        )
      }
  }

  private func ratingBuckets(from ratings: [Double]) -> [TasteRatingBucket] {
    let buckets: [(String, (Double) -> Bool)] = [
      ("9-10", { $0 >= 9 && $0 <= 10 }),
      ("7-8", { $0 >= 7 && $0 < 9 }),
      ("5-6", { $0 >= 5 && $0 < 7 }),
      ("1-4", { $0 >= 1 && $0 < 5 }),
    ]
    let maxCount = max(1, buckets.map { bucket in ratings.filter(bucket.1).count }.max() ?? 1)
    return buckets.map { label, contains in
      let count = ratings.filter(contains).count
      return TasteRatingBucket(label: label, count: count, fraction: Double(count) / Double(maxCount))
    }
  }
}
