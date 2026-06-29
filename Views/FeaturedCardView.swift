import SwiftUI

// Temporary shim to satisfy references until Title model is updated
extension Title {
  var originalName: String? { nil }
  var originalTitle: String? { nil }
}

struct FeaturedCardView: View {
  let title: Title
  var textlessPosterPath: String? = nil
  var logoPath: String? = nil
  
  /// Computed property to get the best poster path, prioritizing textless
  private var displayPosterPath: String? {
    // 1. If explicitly passed textless path, use it
    if let textless = textlessPosterPath, !textless.isEmpty {
      return textless
    }
    
    // 2. Try to get textless poster from title.images.posters
    if let posters = title.images?.posters, !posters.isEmpty {
      // Filter for textless posters (iso6391 == nil)
      let textlessPosters = posters.filter { $0.iso6391 == nil }
      // Sort by vote average descending to get the best one
      if let bestTextless = textlessPosters.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
        return bestTextless.filePath
      }
    }
    
    // 3. Fallback to regular poster path
    return title.posterPath
  }

  var body: some View {
    ZStack(alignment: .top) {
      // 1. Blurred Background (Fills the aspect ratio)
      TMDBImage(path: displayPosterPath) { image in
        image
          .resizable()
          .scaledToFill()
          .frame(width: 300, height: 450)
          .clipped()
          .blur(radius: 20)
          .overlay(Color.black.opacity(0.3))
      } placeholder: {
        Color.gray.opacity(0.3)
          .frame(width: 300, height: 450)
      }
      .id(displayPosterPath)

      // 2. Main Poster (Fit to width, sitting at the top)
      TMDBImage(path: displayPosterPath) { image in
        image
          .resizable()
          .scaledToFill()
          .frame(width: 300, height: 450)
          .clipped()
          .cornerRadius(10)
          .mask(
            LinearGradient(
              colors: [.black, .black, .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          )
      } placeholder: {
        ProgressView()
          .frame(width: 300, height: 450)
      }
      .id(displayPosterPath)

      // 3. Text Overlay (Aligned Bottom)
      VStack {
        Spacer()
        VStack(alignment: .leading, spacing: 4) {
          // Gradient Blur overlay for text legibility
          Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
              LinearGradient(
                colors: [.clear, .black, .black],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(height: 130)  // Increased height to accommodate description
            .overlay(
              VStack(alignment: .leading, spacing: 4) {
                if let logo = logoPath {
                  TMDBImage(path: logo) { image in
                    image.resizable()
                      .scaledToFit()
                      .frame(height: 50)
                      .frame(maxWidth: 180, alignment: .leading)
                      .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                  } placeholder: {
                     // Fallback to text while loading if needed, or empty
                     Text(title.name ?? title.title ?? "Unknown")
                      .font(.title3)
                      .fontWeight(.bold)
                      .foregroundStyle(.white)
                      .lineLimit(1)
                  }
                } else {
                  Text(title.name ?? title.title ?? "Unknown")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                }

                // 2-line description
                if let overview = title.overview, !overview.isEmpty {
                  Text(overview)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
              }
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading), alignment: .bottom
            )
        }
      }
      .frame(width: 300)
      .aspectRatio(2 / 3, contentMode: .fill)
    }
    .frame(width: 300, height: 450)
    .clipped()
    .clipShape(RoundedRectangle(cornerRadius: 30))
  }
}

#Preview {
  FeaturedCardView(title: Title.previewTitles[0])
}
