import Combine
import SwiftUI

@MainActor
class ImageLoader: ObservableObject {
  @Published var image: UIImage? = nil
  @Published var isLoading = false
  @Published var error: Error? = nil

  private var cancellable: AnyCancellable?
  private static let cache = NSCache<NSURL, UIImage>()

  static func cachedImage(for url: URL) async throws -> UIImage {
    if let cached = cache.object(forKey: url as NSURL) {
      return cached
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    guard let image = UIImage(data: data) else {
      throw URLError(.cannotDecodeContentData)
    }
    cache.setObject(image, forKey: url as NSURL)
    return image
  }

  func load(url: URL) {
    // Check cache first
    if let cached = Self.cache.object(forKey: url as NSURL) {
      self.image = cached
      return
    }

    if isLoading { return }
    isLoading = true

    cancellable = URLSession.shared.dataTaskPublisher(for: url)
      .map { UIImage(data: $0.data) }
      .replaceError(with: nil)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] loadedImage in
        guard let self = self else { return }
        self.isLoading = false
        if let loadedImage = loadedImage {
          Self.cache.setObject(loadedImage, forKey: url as NSURL)
          self.image = loadedImage
        } else {
          // Failure
          self.error = URLError(.badServerResponse)
        }
      }
  }
}
