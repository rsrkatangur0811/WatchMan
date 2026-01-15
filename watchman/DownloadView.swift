import SwiftData
import SwiftUI

@available(iOS 26.0, *)
struct DownloadView: View {
  @Query(sort: \Title.title) var savedTitles: [Title]

  var body: some View {
    NavigationStack {
      if savedTitles.isEmpty {
        Text("No Downloads")
          .padding()
          .font(.title3)
          .bold()
      } else {
        VerticalListView(titles: savedTitles, canDelete: true)
      }
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    DownloadView()
  } else {
    Text("Requires iOS 26.0+")
  }
}
