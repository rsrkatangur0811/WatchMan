import SwiftUI

@available(iOS 26.0, *)
struct CountryLanguageView: View {
  @State private var selectedTab: Tab = .country
  @State private var searchText = ""
  @State private var countries: [TMDBClient.Country] = []
  @State private var languages: [TMDBClient.Language] = []
  @State private var isLoading = true
  @Namespace private var animation  // For pill animation

  enum Tab: String, CaseIterable {
    case country = "Country"
    case language = "Language"
  }

  var filteredCountries: [TMDBClient.Country] {
    if searchText.isEmpty { return countries }
    return countries.filter {
      $0.english_name.localizedCaseInsensitiveContains(searchText)
        || $0.native_name.localizedCaseInsensitiveContains(searchText)
    }
  }

  var filteredLanguages: [TMDBClient.Language] {
    if searchText.isEmpty { return languages }
    return languages.filter {
      $0.english_name.localizedCaseInsensitiveContains(searchText)
        || $0.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        gradient: Gradient(colors: [Color.black, Color.white.opacity(0.15)]),
        startPoint: .top,
        endPoint: UnitPoint(x: 0.5, y: 1.2)
      )
      .ignoresSafeArea()

      ZStack(alignment: .top) {
        if isLoading {
          ProgressView()
            .frame(maxHeight: .infinity)
        } else {
          List {
            if selectedTab == .country {
              ForEach(filteredCountries) { country in
                NavigationLink(
                  destination: AttributeResultsView(
                    title: country.english_name,
                    attributeValue: country.iso_3166_1,
                    attributeType: .country
                  )
                ) {
                  HStack {
                    Text(countryFlag(country.iso_3166_1))
                      .font(.title2)
                    VStack(alignment: .leading) {
                      Text(country.english_name)
                        .font(.netflixSans(.medium, size: 16))
                        .foregroundStyle(.white)
                      if !country.native_name.isEmpty && country.native_name != country.english_name
                      {
                        Text(country.native_name)
                          .font(.netflixSans(.light, size: 13))
                          .foregroundStyle(.gray)
                      }
                    }
                  }
                  .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
              }
            } else {
              ForEach(filteredLanguages) { language in
                NavigationLink(
                  destination: AttributeResultsView(
                    title: language.english_name,
                    attributeValue: language.iso_639_1,
                    attributeType: .language
                  )
                ) {
                  VStack(alignment: .leading) {
                    Text(language.english_name)
                      .font(.netflixSans(.medium, size: 16))
                      .foregroundStyle(.white)
                    if !language.name.isEmpty && language.name != language.english_name {
                      Text(language.name)
                        .font(.netflixSans(.light, size: 13))
                        .foregroundStyle(.gray)
                    }
                  }
                  .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
              }
            }
          }
          .listStyle(.plain)
          .safeAreaPadding(.top, 70)  // Push content down to clear the header
          .safeAreaPadding(.bottom, 80)  // Push content up to clear the search bar
        }

        // Pill Style Picker (Floating Header)
        HStack(spacing: 0) {
          ForEach(Tab.allCases, id: \.self) { tab in
            Button {
              let impact = UIImpactFeedbackGenerator(style: .light)
              impact.impactOccurred()
              withAnimation(.snappy) {
                selectedTab = tab
              }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: tab == .country ? "globe" : "bubble.left.and.bubble.right")
                  .font(.system(size: 16, weight: .medium))
                Text(tab.rawValue)
                  .font(.netflixSans(.medium, size: 15))
              }
              .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.7))
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background {
                if selectedTab == tab {
                  Capsule()
                    .fill(Color.white.opacity(0.15))
                    .matchedGeometryEffect(id: "tabPill", in: animation)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(4)
        .background {
          Capsule()
            .fill(.clear)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.vertical, 10)

        // Floating Bottom Search Bar
        VStack {
          Spacer()
          HStack {
            Image(systemName: "magnifyingglass")
              .foregroundStyle(.gray)
            TextField(
              "Search \(selectedTab == .country ? "countries" : "languages")", text: $searchText
            )
            .font(.netflixSans(.medium, size: 15))  // Match Categories font
            .foregroundStyle(.white)
            .tint(.white)
            if !searchText.isEmpty {
              Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                searchText = ""
              }) {
                Image(systemName: "xmark.circle.fill")
                  .foregroundStyle(.gray)
              }
            }
          }
          .padding(.horizontal, 16)  // Match inner button padding
          .padding(.vertical, 8)  // Reduced from 10 to 8 to account for TextField height
          // .frame(height: 52)     // Removed fixed height to let content sizing take over
          .background {
            // Match outer container logic (no padding(4) here because we want search bar full width inside padding?)
            // Actually, Categories has .padding(4) surrounding the buttons.
            // So Search Bar content (HStack) is like the button content.
          }
          .padding(4)  // Match outer container padding
          .background {
            Capsule()
              .fill(.clear)  // Match Categories
              .glassEffect(.regular, in: .capsule)
              .overlay(
                Capsule()
                  .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
              )
          }
          .padding(.horizontal)
          .padding(.bottom, 8)
        }
      }
    }
    .navigationTitle("Browse by")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      do {
        async let fetchedCountries = TMDBClient.shared.fetchCountries()
        async let fetchedLanguages = TMDBClient.shared.fetchLanguages()

        // Parallel fetch
        let (c, l) = try await (fetchedCountries, fetchedLanguages)

        self.countries = c
        self.languages = l
        self.isLoading = false
      } catch {
        print("Error fetching config: \(error)")
        self.isLoading = false
      }
    }
  }

  // Helper to convert ISO country code to Emoji flag
  private func countryFlag(_ countryCode: String) -> String {
    let base: UInt32 = 127397
    var s = ""
    for v in countryCode.unicodeScalars {
      s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
    }
    return String(s)
  }
}
