import SwiftUI

struct FullScreenCategoryMenu: View {
  @Binding var isPresented: Bool
  @Binding var selectedFilter: HomeView.HomeFilter?
  let genres: [Genre]
  let countryName: String
  var onSelectCountry: () -> Void
  var onSelect: (Genre) -> Void

  var body: some View {
    ZStack {
      // 1. Blurred Background
      Rectangle()
        .fill(.regularMaterial)
        .ignoresSafeArea()

      // 2. Content
      VStack(alignment: .leading, spacing: 25) {
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 30) {
            Button(action: {
              let impact = UIImpactFeedbackGenerator(style: .light)
              impact.impactOccurred()
              onSelectCountry()
              withAnimation { isPresented = false }
            }) {
              Text(countryName)
                .font(.netflixSans(.light, size: 22))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(genres) { genre in
              Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onSelect(genre)
                withAnimation { isPresented = false }
              }) {
                Text(genre.name)
                  .font(.netflixSans(.light, size: 22))
                  .foregroundStyle(.white.opacity(0.7))
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
          .padding(.horizontal, 30)
          .padding(.top, 20)
          .padding(.bottom, 100)  // Space for close button
        }
      }

      // 3. Close Button (Bottom Center)
      VStack {
        Spacer()
        Button(action: {
          let impact = UIImpactFeedbackGenerator(style: .medium)
          impact.impactOccurred()
          withAnimation { isPresented = false }
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.black)
            .frame(minWidth: 76)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(radius: 10)
        }
        .padding(.bottom, 20)
      }
    }
    // Removed duplicate background(.ultraThinMaterial) and let the ZStack layer handle it
    .colorScheme(.dark)  // Force dark mode for white text
  }
}
