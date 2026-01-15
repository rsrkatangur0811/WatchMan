import Foundation
import SwiftUI

struct Constants {
  static let homeString = "Home"
  static let upcomingString = "Upcoming"
  static let searchString = "Search"
  static let downloadString = "Download"
  static let playString = "Play"
  static let trendingMovieString = "Trending Movies"
  static let trendingTVString = "Trending TV"
  static let topRatedMovieString = "Top Rated Movies"
  static let topRatedTVString = "Top Rated TV"
  static let movieSearchString = "Movie Search"
  static let tvSearchString = "TV Search"
  static let searchPlaceholderString = "Search movies, shows..."
  static let moviePlaceHolderString = "Search for a Movie"
  static let tvPlaceHolderString = "Search for a TV Show"

  static let discoverString = "Discover"
  static let forYouString = "For You"
  static let showsString = "Shows"
  static let moviesString = "Movies"
  static let categoriesString = "Categories"
  static let featuredMoviesString = "Featured Movies and TV"
  static let featuredSubtitleString = "Popular and trending content"
  static let inTheatresString = "In Theatres"
  static let inTheatresSubtitleString = "Discover the latest theatrical releases"

  static let homeIconString = "house"
  static let upcomingIconString = "play.circle"
  static let searchIconString = "magnifyingglass"
  static let downloadIconString = "arrow.down.to.line"
  static let tvIconString = "tv"
  static let movieIconString = "movieclapper"

  static let testTitleURL = "https://image.tmdb.org/t/p/w500/nnl6OWkyPpuMm595hmAxNW3rZFn.jpg"
  static let testTitleURL2 = "https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg"
  static let testTitleURL3 = "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg"

  static let posterURLStart = "https://image.tmdb.org/t/p/w500"

  static func addPosterPath(to titles: inout [Title]) {
    for index in titles.indices {
      if let path = titles[index].posterPath, !path.isEmpty, !path.contains("http") {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        titles[index].posterPath = Constants.posterURLStart + cleanPath
      }
    }
  }
}

struct Genre: Identifiable, Hashable {
  let id: Int
  let name: String
  var tvId: Int? = nil

  func id(for context: String?) -> Int {
    if context == "tv", let tvId = tvId {
      return tvId
    }
    return id
  }

  static let allGenres: [Genre] = [
    Genre(id: 28, name: "Action", tvId: 10759),
    Genre(id: 12, name: "Adventure", tvId: 10759),
    Genre(id: 16, name: "Animation"),
    Genre(id: 35, name: "Comedy"),
    Genre(id: 80, name: "Crime"),
    Genre(id: 99, name: "Documentary"),
    Genre(id: 18, name: "Drama"),
    Genre(id: 10751, name: "Family"),
    Genre(id: 14, name: "Fantasy", tvId: 10765),
    Genre(id: 36, name: "History"),
    Genre(id: 27, name: "Horror"),
    Genre(id: 10402, name: "Music"),
    Genre(id: 9648, name: "Mystery"),
    Genre(id: 10749, name: "Romance"),
    Genre(id: 878, name: "Science Fiction", tvId: 10765),
    Genre(id: 10770, name: "TV Movie"),
    Genre(id: 53, name: "Thriller"),
    Genre(id: 10752, name: "War", tvId: 10768),
    Genre(id: 37, name: "Western"),
  ]
}

enum YoutubeURLStrings: String {
  case trailer = "trailer"
  case queryShorten = "q"
  case space = " "
  case key = "key"
}

extension Text {
  func ghostButton() -> some View {
    self
      .frame(width: 100, height: 50)
      .foregroundStyle(.buttonText)
      .bold()
      .background {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(.buttonBorder, lineWidth: 5)
      }
  }
}

extension Text {
  func errorMessage() -> some View {
    self
      .foregroundStyle(.red)
      .padding()
      .background(.ultraThinMaterial)
      .clipShape(.rect(cornerRadius: 10))
  }
}
