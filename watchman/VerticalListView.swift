import SwiftUI

@available(iOS 26.0, *)
@available(iOS 26.0, *)
struct VerticalListView: View {
  var titles: [Title]
  let canDelete: Bool
  @Environment(\.modelContext) var modelContext

  var body: some View {
    List(titles) { title in
      NavigationLink {
        TitleDetailView(title: title)
      } label: {
        TMDBImage(path: title.posterPath) { image in
          HStack {
            image
              .resizable()
              .scaledToFit()
              .clipShape(.rect(cornerRadius: 10))
              .padding(5)

            Text((title.name ?? title.title) ?? "")
              .font(.system(size: 14))
              .bold()
          }
        } placeholder: {
          ProgressView()
        }
        .frame(height: 150)
      }
      .swipeActions(edge: .trailing) {
        if canDelete {
          Button {
            modelContext.delete(title)
            try? modelContext.save()
          } label: {
            Image(systemName: "trash")
              .tint(.red)
          }
        }
      }

    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    VerticalListView(titles: Title.previewTitles, canDelete: true)
  } else {
    Text("Requires iOS 26.0+")
  }
}
