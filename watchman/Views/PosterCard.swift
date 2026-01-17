import SwiftUI

struct PosterCard: View {
  let title: Title
  var width: CGFloat? = 140
  var height: CGFloat? = 210
  var namespace: Namespace.ID? = nil
  var sourceID: String? = nil
  var showBorder: Bool = false
  var onFailure: (() -> Void)? = nil

  var body: some View {
    TMDBImage(path: title.posterPath, onFailure: onFailure) { image in
      image
        .resizable()
        .if(width != nil && height != nil) { view in
          view
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
        }
        .if(width == nil || height == nil) { view in
          view.scaledToFit()
        }
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
    } placeholder: {
      RoundedRectangle(cornerRadius: 22)
        .fill(Color.gray.opacity(0.3))
        .frame(width: width, height: height)
    }
    .if(namespace != nil && sourceID != nil) { view in
      view.matchedTransitionSource(id: sourceID!, in: namespace!) { config in
        config.clipShape(RoundedRectangle(cornerRadius: 22))
      }
    }
  }
}
