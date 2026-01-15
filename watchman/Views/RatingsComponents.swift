import SwiftUI

struct RatingsInfoView: View {
  let title: Title

  var body: some View {
    HStack(spacing: 12) {
      // IMDb Score
      if let voteAverage = title.voteAverage, voteAverage > 0 {
        RatingPill(
          logo: "IMDbLogo", value: String(format: "%.1f", voteAverage), isWideLogo: true,
          logoSize: 14)
      }

      // Critics Score (Rotten Tomatoes Style)
      if let critics = title.criticsScore, critics > 0 {
        RatingPill(logo: "TomatoLogo", value: "\(critics)%")
      }

      // Audience Score (Popcorn)
      if let audience = title.audienceScore, audience > 0 {
        RatingPill(logo: "PopcornLogo", value: "\(audience)%")
      }

      // Letterboxd Score
      if let letterboxd = title.letterboxdScore, letterboxd > 0 {
        RatingPill(logo: "LetterboxdLogo", value: String(format: "%.1f", letterboxd), logoSize: 26)
      }
    }
    .fixedSize(horizontal: true, vertical: false) // Allow expansion beyond borders without wrapping
    .frame(maxWidth: .infinity)  // Center alignment when fitting, overflow when too wide
    .padding(.vertical, 8)
  }
}

// Helper View for Rating Pills
struct RatingPill: View {
  let logo: String
  let value: String
  var isWideLogo: Bool = false
  var logoSize: CGFloat = 14

  var body: some View {
    HStack(spacing: 6) {
      Image(logo)
        .resizable()
        .scaledToFit()
        .frame(height: logoSize)  // Actual image size
        .frame(height: 18)  // Consistent container height for alignment
        .frame(maxWidth: isWideLogo ? 28 : 22)  // Consistent width constraint logic

      Text(value)
        .font(.subheadline)
        .bold()
        .foregroundStyle(.white)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .overlay(
      Capsule()
        .stroke(Color.white.opacity(0.3), lineWidth: 1)  // Thin pill outline
    )
  }
}
