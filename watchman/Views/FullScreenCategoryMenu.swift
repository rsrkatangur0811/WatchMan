import SwiftUI

@available(iOS 26.0, *)
struct FullScreenCategoryMenu: View {
  @Binding var isPresented: Bool
  @Binding var selectedFilter: HomeView.HomeFilter?
  let genres: [Genre]
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
            .frame(width: 60, height: 60)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 10)
        }
        .padding(.bottom, 20)
      }
    }
    // Removed duplicate background(.ultraThinMaterial) and let the ZStack layer handle it
    .colorScheme(.dark)  // Force dark mode for white text
  }
}
