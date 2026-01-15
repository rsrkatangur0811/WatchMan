import SwiftUI

@available(iOS 26.0, *)
@available(iOS 26.0, *)
struct SearchResultsView: View {
  @Binding var isSearchActive: Bool
  var animation: Namespace.ID
  
  @State private var searchText = ""
  @State private var isSearching = false
  @FocusState private var isSearchFieldFocused: Bool
  @State private var showSearchTopBlur = false
  @State private var searchViewModel = SearchViewModel() // Fixed: @State instead of @StateObject
  var heroNamespace: Namespace.ID
  
  var body: some View {
    ZStack {
      // Background
      Color.black.ignoresSafeArea()
      LinearGradient(
        gradient: Gradient(colors: [Color.black, Color.white.opacity(0.15)]),
        startPoint: .top,
        endPoint: UnitPoint(x: 0.5, y: 1.2)
      )
      .ignoresSafeArea()
      
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 20) {
          
          if let error = searchViewModel.errorMessage {
            Text(error)
              .foregroundStyle(.red)
              .padding()
              .background(.ultraThinMaterial)
              .clipShape(.rect(cornerRadius: 10))
          }
          
          if searchText.isEmpty {
            // ... (Browse By section unchanged) ...
             VStack(alignment: .leading, spacing: 20) {
              Text("Browse by")
                .font(.netflixSans(.bold, size: 22))
                .foregroundStyle(.white)
                .padding(.horizontal)
              
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
            }
            .padding(.top, 20)
          } else {
            // Search Results Grid
            if isSearching { // Use local isSearching state
              ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 50)
            } else if !searchViewModel.searchPeople.isEmpty || !searchViewModel.searchTitles.isEmpty {
              // Results grouped by Person / Movie / TV
              LazyVStack(alignment: .leading, spacing: 30) {
                // People
                if !searchViewModel.searchPeople.isEmpty {
                  VStack(alignment: .leading, spacing: 15) {
                    Text("People")
                      .font(.netflixSans(.bold, size: 20))
                      .foregroundStyle(.white)
                      .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                      LazyHStack(spacing: 15) {
                        ForEach(searchViewModel.searchPeople) { person in
                          NavigationLink(
                            destination: PersonDetailView(
                              personId: person.id,
                              name: person.name,
                              profileURL: person.profileURL
                            )
                          ) {
                            VStack(spacing: 8) {
                              TMDBImage(path: person.profilePath, size: .w300) { image in
                                image.resizable().scaledToFill()
                              } placeholder: {
                                ZStack {
                                  Color.gray.opacity(0.3)
                                  Image(systemName: "person.fill")
                                    .foregroundStyle(.white.opacity(0.5))
                                }
                              }
                              .frame(width: 100, height: 100)
                              .clipShape(Circle())
                              .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                              
                              Text(person.name)
                                .font(.netflixSans(.medium, size: 13))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 100)
                            }
                          }
                        }
                      }
                      .padding(.horizontal)
                    }
                  }
                }
                
                // Titles (Movies & Shows)
                if !searchViewModel.searchTitles.isEmpty {
                  VStack(alignment: .leading, spacing: 15) {
                    Text("Titles")
                      .font(.netflixSans(.bold, size: 20))
                      .foregroundStyle(.white)
                      .padding(.horizontal)
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                    LazyVGrid(columns: columns, spacing: 12) {
                      ForEach(searchViewModel.searchTitles) { title in
                        let searchSourceID = "search_\(title.id ?? 0)"
                        NavigationLink(destination: 
                          TitleDetailView(title: title)
                            .navigationTransition(.zoom(sourceID: searchSourceID, in: heroNamespace))
                        ) {
                           PosterCard(
                              title: title,
                              width: nil, height: nil,
                              namespace: heroNamespace,
                              sourceID: searchSourceID,
                              showBorder: true
                           )
                           .id(searchSourceID)
                           .aspectRatio(2 / 3, contentMode: .fit)
                        }
                      }
                    }
                    .padding(.horizontal)
                  }
                }
              }
              .padding(.bottom, 100) // Spacing for bottom
            } else if !isSearching { // Not loading and no results
              ContentUnavailableView(
                 "No results found",
                 systemImage: "magnifyingglass",
                 description: Text("Try searching for something else")
              )
              .padding(.top, 50)
            }
          }
        }
      }
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top
      } action: { oldValue, newValue in
        withAnimation {
          showSearchTopBlur = newValue > 20
        }
      }
      .safeAreaInset(edge: .top) {
        searchHeaderBar
      }
      .ignoresSafeArea(edges: .top)
      .scrollDismissesKeyboard(.immediately) // Dismiss keyboard on scroll
    }
    .onTapGesture {
      isSearchFieldFocused = false // Dismiss keyboard on background tap
    }
    .task(id: searchText) {
      guard !searchText.isEmpty else { return }
      
      isSearching = true // Start loading
      searchViewModel.clearResults()
      
      try? await Task.sleep(for: .milliseconds(500))
      
      if Task.isCancelled {
        return
      }
      
      await searchViewModel.getSearchTitles(by: "multi", for: searchText)
      isSearching = false // Stop loading
    }
    .onAppear {
      isSearchFieldFocused = true
    }
  }
  
  // Search header bar for search results view
  @ViewBuilder
  private var searchHeaderBar: some View {
    VStack(alignment: .leading, spacing: 15) {
      // Title row
      Text("Search")
        .font(.netflixSans(.bold, size: 34))
        .foregroundStyle(.white)
        .padding(.horizontal)
      
      // Search bar row with back button
      HStack(spacing: 10) {
        // Back button (outline pill style) - Check if text exists to hide
        if searchText.isEmpty {
          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.snappy) {
              isSearchActive = false
              // No need to clear text/results here as view will dealloc, 
              // but purely for visual cleanup if it stays alive:
              // searchText = "" 
              isSearchFieldFocused = false
            }
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .medium))
              .frame(height: 38) // Reduced height to match filter pills
              .padding(.horizontal, 20)
              .background(Color.clear)
              .clipShape(Capsule())
              .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.6)
              )
          }
          .foregroundStyle(.white)
          .transition(.move(edge: .leading).combined(with: .opacity))
        }
        
        // Search bar
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
          
          TextField("Search movies, shows...", text: $searchText)
            .font(.netflixSans(.medium, size: 15)) // Reduce font to 15
            .foregroundStyle(.white)
            .focused($isSearchFieldFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
          
          if !searchText.isEmpty {
            Button(action: {
              let impact = UIImpactFeedbackGenerator(style: .light)
              impact.impactOccurred()
              withAnimation(.snappy) {
                searchText = ""
                searchViewModel.clearResults()
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.5))
            }
          }
        }
        .padding(.horizontal, 14)
        .frame(height: 38) // Reduced height to match filter pills
        .background(Color.white.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
          Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.6)
        )
        // Add matchedGeometry to the search bar container
        .matchedGeometryEffect(id: "SearchBar", in: animation)
      }
      .animation(.snappy, value: searchText.isEmpty)
      .padding(.horizontal)
    }
    .padding(.top, 60)
    .padding(.bottom, 15)
    .background(
      Color.clear
        .glassEffect(
          .regular,
          in: UnevenRoundedRectangle(
            topLeadingRadius: UIScreen.screenCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: UIScreen.screenCornerRadius,
            style: .continuous
          )
        )
        .opacity(showSearchTopBlur ? 1 : 0) // Fade in glass effect on scroll
        .ignoresSafeArea(edges: .top)
    )
  }
}
