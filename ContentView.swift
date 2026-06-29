import SwiftUI

enum TabItem: String, CaseIterable {
  case discover = "Discover"
  case search = "Search"
  case library = "Library"
}

struct TabBarVisibilityPreferenceKey: PreferenceKey {
  static var defaultValue: Bool = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

struct ContentView: View {
  @State private var selectedTab: TabItem = .discover
  @State private var isTabBarHidden: Bool = false
  @State private var isSearchActive: Bool = false
  @ObservedObject private var letterboxdSyncService = LetterboxdSyncService.shared

  @Environment(\.modelContext) private var modelContext

  @Namespace private var animation
  @Namespace private var heroNamespace

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
          // Main Content
          TabView(selection: $selectedTab) {
            HomeView(isSearchActive: $isSearchActive)
              .tag(TabItem.discover)
              .accessibilityLabel(TabItem.discover.rawValue)
              .tabItem {
                Image(systemName: selectedTab == .discover ? "house.fill" : "house")
              }

            SearchResultsView(
                isSearchActive: $isSearchActive,
                animation: animation,
                heroNamespace: heroNamespace
              )
              .tag(TabItem.search)
              .accessibilityLabel(TabItem.search.rawValue)
              .tabItem {
                Image(systemName: "magnifyingglass")
              }
            
            LibraryView()
              .tag(TabItem.library)
              .accessibilityLabel(TabItem.library.rawValue)
              .tabItem {
                Image(systemName: selectedTab == .library ? "bookmark.fill" : "bookmark")
              }
          }
          .environment(\.symbolVariants, .none)
      }

      .preferredColorScheme(.dark)
      .onAppear {
        UserLibraryManager.shared.setModelContext(modelContext)
        letterboxdSyncService.setModelContext(modelContext)
      }
      .environmentObject(letterboxdSyncService)
    }
    .enablesInteractivePopGesture()
  }
}

#Preview {
  ContentView()
    .modelContainer(for: [UserLibraryItem.self, WatchedEpisode.self])
}
