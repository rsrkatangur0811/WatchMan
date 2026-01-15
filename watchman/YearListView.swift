import SwiftUI

@available(iOS 26.0, *)
struct YearListView: View {
  let decade: Int

  var years: [Int] {
    // Generate years for the decade in descending order
    (0..<10).map { decade + $0 }.reversed()
  }

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
          // "Any" Option
          NavigationLink(
            destination: YearResultsView(title: "\(decade)s", year: nil, decade: decade)
          ) {
            HStack {
              Text("Any")
                .font(.body)
                .foregroundStyle(.white)
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.1))
          }
          Divider().background(Color.white.opacity(0.2))

          // Specific Years
          ForEach(years, id: \.self) { year in
            NavigationLink(
              destination: YearResultsView(title: String(year), year: year, decade: nil)
            ) {
              HStack {
                Text(String(year))
                  .font(.body)
                  .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.gray)
              }
              .padding()
              .background(Color.white.opacity(0.1))
            }
            if year != years.last {
              Divider().background(Color.white.opacity(0.2))
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
      }
    }
    .navigationTitle("Year")
    .navigationBarTitleDisplayMode(.inline)
  }
}
