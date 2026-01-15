import SwiftUI

@available(iOS 26.0, *)
struct DecadeListView: View {
  let decades = [2020, 2010, 2000, 1990, 1980, 1970, 1960, 1950, 1940, 1930, 1920]

  var body: some View {
    ZStack {
      // Background
      Color.black.ignoresSafeArea()

      // Subtle Gradient
      LinearGradient(
        gradient: Gradient(colors: [Color.black, Color.white.opacity(0.15)]),
        startPoint: .top,
        endPoint: UnitPoint(x: 0.5, y: 1.2)
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 0) {
          ForEach(decades, id: \.self) { decade in
            NavigationLink(destination: YearListView(decade: decade)) {
              HStack {
                Text("\(String(decade))s")
                  .font(.netflixSans(.medium, size: 17))
                  .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.gray)
              }
              .padding()
              .background(Color.white.opacity(0.1))
            }
            Divider().background(Color.white.opacity(0.2))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
      }
    }
    .navigationTitle("Decade")
    .navigationBarTitleDisplayMode(.inline)
  }
}
