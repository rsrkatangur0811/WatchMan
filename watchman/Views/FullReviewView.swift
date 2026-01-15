import SwiftUI

@available(iOS 26.0, *)
struct FullReviewView: View {
  let review: Review
  let dismissAction: () -> Void

  var body: some View {
    ZStack {
      // Dimmed background
      Color.black.opacity(0.6)
        .ignoresSafeArea()
        .onTapGesture {
          dismissAction()
        }

      // Glass Card
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text("FULL SPOILER-FREE REVIEW @")
              .font(.netflixSans(.medium, size: 14))
              .foregroundStyle(.white.opacity(0.7))
              .padding(.top, 10)

            Text(review.url ?? "")
              .font(.netflixSans(.medium, size: 14))
              .foregroundStyle(.white.opacity(0.7))
              .multilineTextAlignment(.leading)

            Text(review.content)
              .font(.netflixSans(.medium, size: 17))
              .foregroundStyle(.white)
              .multilineTextAlignment(.leading)
              .lineSpacing(4)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 24)
          .padding(.bottom, 80)  // Space for floating button
        }
        .mask(
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: 0.05),
              .init(color: .black, location: 0.85),
              .init(color: .clear, location: 1),
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
        )

        // Dismiss Button
        Button {
          dismissAction()
        } label: {
          Text("Dismiss")
            .font(.netflixSans(.bold, size: 17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              ZStack {
                Color.clear
                  .glassEffect(.regular, in: .capsule)
                Color.blue.opacity(0.3)
                  .clipShape(Capsule())
              }
            )
            .clipShape(Capsule())
            .overlay(
              Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity, maxHeight: 600)
      .background(
        Color.black.opacity(0.3)
          .glassEffect(.regular, in: .rect(cornerRadius: 30))
      )
      .clipShape(RoundedRectangle(cornerRadius: 30))
      .overlay(
        RoundedRectangle(cornerRadius: 30)
          .stroke(Color.white.opacity(0.2), lineWidth: 1)
      )
      .padding(.horizontal, 20)
    }
    .transition(.opacity)
    .zIndex(100)  // Ensure it sits on top
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    FullReviewView(
      review: Review(
        id: "1",
        author: "CodeOfCinema",
        content:
          "Avatar: Fire and Ash leaves me with mixed feelings of technical admiration and creative exhaustion. It's a film that lives off its scale, scope, and technical audacity but fails to take the step forward the narrative required to become memorable on its own merit.\n\nCinema cannot just be a technical showcase; it must also be an emotional journey.",
        createdAt: "2025-12-25",
        url: "https://movieswetextedabout.com/avatar-fire-and-ash..."
      ),
      dismissAction: {}
    )
  }
}
