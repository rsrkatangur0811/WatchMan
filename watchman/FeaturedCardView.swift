import SwiftUI

// Temporary shim to satisfy references until Title model is updated
// Temporary shim to satisfy references until Title model is updated
extension Title {
  var originalName: String? { nil }
  var originalTitle: String? { nil }

}

struct FeaturedCardView: View {
  let title: Title

  var body: some View {
    ZStack(alignment: .top) {
      // 1. Blurred Background (Fills the aspect ratio)
      // 1. Blurred Background (Fills the aspect ratio)
      TMDBImage(path: title.posterPath) { image in
        image
          .resizable()
          .scaledToFill()
          .frame(width: 300)
          .aspectRatio(3 / 4, contentMode: .fill)
          .clipped()
          .blur(radius: 20)
          .overlay(Color.black.opacity(0.3))
      } placeholder: {
        Color.gray.opacity(0.3)
          .frame(width: 300)
          .aspectRatio(3 / 4, contentMode: .fill)
      }

      // 2. Main Poster (Fit to width, sitting at the top)
      // 2. Main Poster (Fit to width, sitting at the top)
      TMDBImage(path: title.posterPath) { image in
        image
          .resizable()
          .scaledToFill()
          .frame(width: 300)
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
          .frame(width: 300, height: 400)
      }

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
            .frame(height: 120)  // Adjust height to cover the bottom area
            .overlay(
              VStack(alignment: .leading, spacing: 4) {
                Text(title.name ?? title.title ?? "Unknown")
                  .font(.title3)
                  .fontWeight(.bold)
                  .foregroundStyle(.white)
                  .lineLimit(1)

                Text(title.overview ?? "")
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.8))
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
              }
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading), alignment: .bottom
            )
        }
      }
      .frame(width: 300)
      .aspectRatio(3 / 4, contentMode: .fill)
    }
    .frame(width: 300)
    .aspectRatio(3 / 4, contentMode: .fill)
    .clipShape(RoundedRectangle(cornerRadius: 30))
  }
}

#Preview {
  FeaturedCardView(title: Title.previewTitles[0])
}
