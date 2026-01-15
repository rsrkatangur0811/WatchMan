import SwiftUI

@available(iOS 26.0, *)
@available(iOS 26.0, *)
struct SearchView: View {
  @State private var searchText = ""
  private let searchViewModel = SearchViewModel()
  @State private var navigationPath = NavigationPath()
  @Namespace private var heroTransition
  @State private var selectedTitle: Title?
  @State private var tappedSourceID: String = ""

  var body: some View {
    ZStack {
      // ... (Background unchanged)
      Color.black.ignoresSafeArea()
      LinearGradient(
        gradient: Gradient(colors: [Color.white.opacity(0.2), Color.black]),
        startPoint: .top,
        endPoint: UnitPoint(x: 0.5, y: 1.5)
      )
      .ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        if let error = searchViewModel.errorMessage {
          Text(error)
            .foregroundStyle(.red)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 10))
        }

        if searchText.isEmpty {
          VStack(alignment: .leading, spacing: 20) {
            Text("Browse by")
              .font(.netflixSans(.bold, size: 22))
              .foregroundStyle(.white)
              .padding(.horizontal)
              .padding(.top)

            VStack(spacing: 0) {
              NavigationLink(destination: DecadeListView()) {
                HStack {
                  Text("Release date")
                    .foregroundStyle(.white)
                    .font(.netflixSans(.medium, size: 17))
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.1))
              }
              .simultaneousGesture(TapGesture().onEnded {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              })
              Divider().background(Color.white.opacity(0.2))

              // Popular Movies
              NavigationLink(
                destination: BrowsingView(
                  title: "Popular Movies", endpoint: "popular",
                  mediaType: "movie")
              ) {
                HStack {
                  Text("Popular Movies")
                    .foregroundStyle(.white)
                    .font(.netflixSans(.medium, size: 17))
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.1))
              }
              .simultaneousGesture(TapGesture().onEnded {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              })
              Divider().background(Color.white.opacity(0.2))

              // Popular Shows
              NavigationLink(
                destination: BrowsingView(
                  title: "Popular Shows", endpoint: "popular",
                  mediaType: "tv")
              ) {
                HStack {
                  Text("Popular Shows")
                    .foregroundStyle(.white)
                    .font(.netflixSans(.medium, size: 17))
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.1))
              }
              .simultaneousGesture(TapGesture().onEnded {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              })

              Divider().background(Color.white.opacity(0.2))

              // Country or Language
              NavigationLink(destination: CountryLanguageView()) {
                HStack {
                  Text("Country or language")
                    .foregroundStyle(.white)
                    .font(.netflixSans(.medium, size: 17))
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.1))
              }
              .simultaneousGesture(TapGesture().onEnded {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              })
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            // End of Browse Section
          }
        } else {
          VStack(alignment: .leading, spacing: 20) {
            // People Results
            if !searchViewModel.searchPeople.filter({ $0.profilePath != nil }).isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("People")
                  .font(.netflixSans(.bold, size: 20))
                  .foregroundStyle(.white)
                  .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(
                      searchViewModel.searchPeople.filter { $0.profilePath != nil }.prefix(10)
                    ) { person in
                      NavigationLink(
                        destination: PersonDetailView(
                          personId: person.id,
                          name: person.name,
                          profileURL: person.profileURL
                        )
                      ) {
                        VStack {
                          AsyncImage(url: person.profileURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                          } placeholder: {
                            ZStack {
                              Color.gray.opacity(0.3)
                              Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.5))
                            }
                          }
                          .frame(width: 80, height: 120)
                          .clipShape(RoundedRectangle(cornerRadius: 12))
                          .overlay(
                            RoundedRectangle(cornerRadius: 12)
                              .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                          )

                          Text(person.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(width: 90, height: 32, alignment: .center)
                        }
                      }
                      .buttonStyle(.plain)
                    }
                  }
                  .padding(.horizontal)
                }
              }
            }

            // Titles Results
            if !searchViewModel.searchTitles.filter({
              $0.posterPath != nil && !$0.posterPath!.isEmpty
            }).isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Movies & Shows")
                  .font(.netflixSans(.bold, size: 20))
                  .foregroundStyle(.white)
                  .padding(.horizontal)

                LazyVGrid(
                  columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                  spacing: 15
                ) {
                  ForEach(
                    searchViewModel.searchTitles.filter {
                      $0.posterPath != nil && !$0.posterPath!.isEmpty
                    }
                  ) { title in
                    let sourceID = "searchResult_\(title.id ?? 0)"
                    PosterCard(
                      title: title, width: nil, height: nil, namespace: heroTransition,
                      sourceID: sourceID, showBorder: true
                    )
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .onTapGesture {
                      tappedSourceID = sourceID
                      selectedTitle = title
                    }
                  }
                }
                .padding(.horizontal)
              }
            }
          }
          .padding(.top)
        }
      }
      .navigationTitle(Constants.searchString)
      .searchable(
        text: $searchText,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: Constants.searchPlaceholderString
      )
      .task(id: searchText) {
        // Clear previous results immediately to prevent stale data flash
        searchViewModel.clearResults()

        try? await Task.sleep(for: .milliseconds(500))

        if Task.isCancelled || searchText.isEmpty {
          return
        }

        // Use "multi" for combined search
        await searchViewModel.getSearchTitles(by: "multi", for: searchText)
      }
      .navigationDestination(for: Title.self) { title in
        TitleDetailView(title: title)
      }
      .navigationDestination(item: $selectedTitle) { title in
        TitleDetailView(title: title)
          .navigationTransition(.zoom(sourceID: tappedSourceID, in: heroTransition))
      }
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    SearchView()
  } else {
    Text("Requires iOS 26.0+")
  }
}
