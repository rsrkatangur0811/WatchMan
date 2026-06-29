import SwiftUI

enum TMDBImageSize: String {
  case w92  // Thumbnails (cast photos)
  case w185  // Small posters
  case w300  // Medium posters
  case w500  // Large posters
  case w780  // Hero backdrops
  case w1280  // Full backdrops
  case original  // Original resolution
}

struct TMDBImage<Content: View, Placeholder: View>: View {
  let path: String?
  let size: TMDBImageSize
  let content: (Image) -> Content
  let placeholder: () -> Placeholder
  var onFailure: (() -> Void)? = nil

  @StateObject private var loader = ImageLoader()

  init(
    path: String?,
    size: TMDBImageSize = .w500,
    onFailure: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Image) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    self.path = path
    self.size = size
    self.onFailure = onFailure
    self.content = content
    self.placeholder = placeholder
  }

  private var finalURL: URL? {
    guard let path, !path.isEmpty else { return nil }
    if path.hasPrefix("http") {
      return URL(string: path)
    } else {
      let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
      return URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\(cleanPath)")
    }
  }

  var body: some View {
    Group {
      if let image = loader.image {
        content(Image(uiImage: image))
      } else if loader.error != nil {
        placeholder()
          .onAppear { onFailure?() }
      } else {
        placeholder()
          .onAppear {
            if let url = finalURL {
              loader.load(url: url)
            }
          }
      }
    }
    .onChange(of: path) { _, _ in
      // Reset and reload if path changes in recycled view
      loader.image = nil
      loader.error = nil  // Reset error too
      if let url = finalURL {
        loader.load(url: url)
      }
    }
  }
}
