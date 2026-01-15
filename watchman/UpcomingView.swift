import SwiftUI

@available(iOS 26.0, *)
@available(iOS 26.0, *)
struct UpcomingView: View {
  let viewModel = ViewModel()

  var body: some View {
      GeometryReader { geo in
        switch viewModel.upcomingStatus {
        case .notStarted:
          EmptyView()
        case .fetching:
          ProgressView()
            .frame(width: geo.size.width, height: geo.size.height)
        case .success:
          VerticalListView(titles: viewModel.upcomingMovies, canDelete: false)
        case .failed(let underlyingError):
          Text(underlyingError.localizedDescription)
            .errorMessage()
            .frame(width: geo.size.width, height: geo.size.height)
        }
      }
      .task {
        await viewModel.getUpcomingMovies()
      }

  }
}

#Preview {
  if #available(iOS 26.0, *) {
    UpcomingView()
  } else {
    Text("Requires iOS 26.0+")
  }
}
