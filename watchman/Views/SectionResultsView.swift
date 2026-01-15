import SwiftUI

@available(iOS 26.0, *)
struct SectionResultsView: View {
  let title: String
  let items: [Title]
  @Environment(\.dismiss) var dismiss

  let columns = [
    GridItem(.adaptive(minimum: 100), spacing: 10)
  ]

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(items) { item in
            NavigationLink(destination: TitleDetailView(title: item)) {
              PosterCard(title: item, width: nil, height: nil)
                .aspectRatio(2 / 3, contentMode: .fit)
            }
          }
        }
        .padding()
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarBackground(.automatic, for: .navigationBar)
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    NavigationStack {
      SectionResultsView(title: "Superhero", items: Title.previewTitles)
    }
  } else {
    Text("Requires iOS 26.0+")
  }
}
