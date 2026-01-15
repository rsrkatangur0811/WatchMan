import SwiftUI

@available(iOS 26.0, *)
struct RatingSheet: View {
  let title: String
  let currentRating: Double?
  let onRate: (Double?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedRating: Double = 5.0

  var body: some View {
    VStack(spacing: 24) {
      // Header
      HStack {
        Button("Cancel") {
          dismiss()
        }
        .foregroundStyle(.gray)

        Spacer()

        Text("Rate")
          .font(.netflixSans(.bold, size: 18))
          .foregroundStyle(.white)

        Spacer()

        Button("Done") {
          onRate(selectedRating)
          dismiss()
        }
        .foregroundStyle(.yellow)
      }
      .padding(.horizontal)
      .padding(.top, 16)

      // Title
      Text(title)
        .font(.netflixSans(.medium, size: 16))
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      // Stars
      HStack(spacing: 8) {
        ForEach(1...10, id: \.self) { star in
          Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
              selectedRating = Double(star)
            }
          } label: {
            Image(systemName: Double(star) <= selectedRating ? "star.fill" : "star")
              .font(.system(size: 28))
              .foregroundStyle(Double(star) <= selectedRating ? .yellow : .gray.opacity(0.5))
          }
          .buttonStyle(.plain)
        }
      }

      // Rating label
      Text("\(Int(selectedRating))/10")
        .font(.netflixSans(.bold, size: 32))
        .foregroundStyle(.white)

      // Clear rating button
      if currentRating != nil {
        Button {
          onRate(nil)
          dismiss()
        } label: {
          Text("Remove Rating")
            .font(.netflixSans(.medium, size: 14))
            .foregroundStyle(.red)
        }
      }

      Spacer()
    }
    .background(Color.black)
    .onAppear {
      if let current = currentRating {
        selectedRating = current
      }
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    RatingSheet(title: "The Matrix", currentRating: 8.0) { rating in
      print("Rated: \(rating ?? 0)")
    }
  }
}
