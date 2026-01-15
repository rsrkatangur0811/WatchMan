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
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .if(showBorder) { view in
          view.overlay(
            RoundedRectangle(cornerRadius: 15)
              .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
          )
        }
    } placeholder: {
      RoundedRectangle(cornerRadius: 15)
        .fill(Color.gray.opacity(0.3))
        .frame(width: width, height: height)
    }
    .if(namespace != nil && sourceID != nil) { view in
      view.matchedTransitionSource(id: sourceID!, in: namespace!) { config in
        config.clipShape(RoundedRectangle(cornerRadius: 15))
      }
    }
  }
}
