import SwiftUI

// MARK: - Circular Profile View (Cast)
struct CircularProfileView: View {
  let cast: Cast

  var body: some View {
    VStack {
      AsyncImage(url: cast.profileURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        ZStack {
          Color.gray.opacity(0.3)
          Image(systemName: "person.fill")
            .font(.title)
            .foregroundStyle(.white.opacity(0.5))
        }
      }
      .frame(width: 80, height: 120)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))

      Text(cast.name)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(width: 90, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)

      if let char = cast.character, !char.isEmpty {
        Text(char)
          .font(.caption2)
          .foregroundStyle(.gray)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .frame(width: 90)
      }
    }
  }
}

// MARK: - Review Card View
struct ReviewCardView: View {
  let review: Review

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(review.author)
          .font(.subheadline)
          .fontWeight(.bold)
          .foregroundStyle(.white)
        Spacer()
      }

      Text(review.content)
        .font(.caption)
        .foregroundStyle(.gray)
        .lineLimit(4)
    }
    .padding()
    .frame(width: 280, height: 140)
    .background {
      RoundedRectangle(cornerRadius: 30)
        .fill(.clear)
        .glassedEffect(in: RoundedRectangle(cornerRadius: 30))
    }
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .overlay(
      RoundedRectangle(cornerRadius: 30)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
  }
}

// MARK: - Trailer Thumbnail View
struct TrailerItemView: View {
  let video: Video

  var body: some View {
    VStack(alignment: .leading) {
      ZStack {
        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.key)/mqdefault.jpg")) {
          image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.black
        }
        .frame(width: 200, height: 112)
        .clipped()
        .cornerRadius(8)

        Image(systemName: "play.fill")
          .font(.system(size: 18, weight: .bold))
          .liquidGlassIconPill(minWidth: 58, height: 42, fillOpacity: 0.22)
      }

      Text(video.name)
        .font(.caption)
        .foregroundStyle(.white)
        .lineLimit(2)
        .frame(width: 200, alignment: .leading)
    }
  }
}

// MARK: - Simple Title Card (for Recommendations/More by Director)
struct SmallTitleCard: View {
  let title: Title
  var namespace: Namespace.ID? = nil
  var sourceID: String? = nil

  var body: some View {
    VStack(alignment: .leading) {
      TMDBImage(path: title.posterPath, size: .w185) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        RoundedRectangle(cornerRadius: 22)
          .fill(Color.gray.opacity(0.3))
      }
      .frame(width: 120, height: 180)
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
            lineWidth: 0.5
          )
      )
      .if(namespace != nil && sourceID != nil) { view in
        view.matchedTransitionSource(id: sourceID!, in: namespace!) { config in
          config.clipShape(RoundedRectangle(cornerRadius: 22))
        }
      }

      Text(title.name ?? title.title ?? "Unknown")
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .lineLimit(1)
    }
    .frame(width: 120)
  }
}
