import SwiftUI

@available(iOS 26.0, *)
struct FloatingRatingPill: View {
  @Binding var rating: Double?  // Internal 0-10 scale
  var onRate: (Double?) -> Void

  @State private var dragRating: Double?
  @State private var componentWidth: CGFloat = 0
  private let horizontalPadding: CGFloat = 20

  // Convert internal 0-10 rating to 0-5 for display
  private var currentDisplayRating: Double {
    let r = dragRating ?? rating ?? 0
    return r / 2.0
  }

  var body: some View {
    HStack(spacing: 8) {
      ForEach(1...5, id: \.self) { index in
        starImage(for: index)
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(currentDisplayRating >= Double(index) - 0.5 ? .yellow : .gray)
      }
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, 12)
    .background {
      Capsule()
        .fill(.clear)
        .glassEffect(.regular, in: .capsule)
    }
    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    .overlay(
      GeometryReader { geo in
        Color.clear
          .onAppear {
            componentWidth = geo.size.width
          }
          .onChange(of: geo.size.width) { _, newValue in
            componentWidth = newValue
          }
      }
    )
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          handleTouch(location: value.location)
        }
        .onEnded { value in
          handleTouch(location: value.location)
          if let r = dragRating {
            if r == 0 {
              rating = nil
              onRate(nil)
            } else {
              rating = r
              onRate(r)
            }
            dragRating = nil
          }
        }
    )
  }

  private func handleTouch(location: CGPoint) {
    let activeWidth = componentWidth - (horizontalPadding * 2)
    let starWidth = activeWidth / 5.0

    // Adjust x for padding
    let relativeX = location.x - horizontalPadding
    let rawRating = Double(relativeX / starWidth)

    // Check for remove gesture (swipe all way to left / off-edge)
    // Threshold: < 0.25 stars (roughly left edge of first star)
    if rawRating < 0.25 {
      dragRating = 0.0
      return
    }

    // Clamp between 0.5 and 5.0 (0 cannot be a rating unless removing)
    let clamped = max(0.5, min(5.0, rawRating))

    // Snap to 0.5 steps
    let step = 0.5
    let snapped = (round(clamped / step) * step)

    // Ensure final snap didn't round down to 0
    let finalStars = max(0.5, snapped)

    // Convert back to 0-10 scale for internal storage
    dragRating = finalStars * 2.0
  }

  private func starImage(for index: Int) -> Image {
    let value = currentDisplayRating
    if value >= Double(index) {
      return Image(systemName: "star.fill")
    } else if value >= Double(index) - 0.5 {
      return Image(systemName: "star.leadinghalf.filled")
    } else {
      return Image(systemName: "star")
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    ZStack {
      Color.gray
      FloatingRatingPill(rating: .constant(7.0)) { _ in }
    }
  }
}
