import SwiftUI

@available(iOS 26.0, *)
enum TabItem: String, CaseIterable {
  case discover = "Discover"
  case library = "Library"
}

struct TabBarVisibilityPreferenceKey: PreferenceKey {
  static var defaultValue: Bool = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

@available(iOS 26.0, *)
struct ContentView: View {
  @State private var selectedTab: TabItem = .discover
  @State private var isTabBarHidden: Bool = false
  @State private var isSearchActive: Bool = false

  @Namespace private var animation
  @Namespace private var heroNamespace

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        // Main Content
        TabView(selection: $selectedTab) {
          HomeView(isSearchActive: $isSearchActive)
            .tag(TabItem.discover)
            .toolbar(.hidden, for: .tabBar) // Hide native bar

          LibraryView()
            .tag(TabItem.library)
            .toolbar(.hidden, for: .tabBar) // Hide native bar
        }

        // Custom Liquid Glass Tab Bar
        if !isTabBarHidden {
          HStack(spacing: 0) {
          ForEach(TabItem.allCases, id: \.self) { tab in
            Button {
              let impact = UIImpactFeedbackGenerator(style: .light)
              impact.impactOccurred()
              withAnimation(.snappy) {
                selectedTab = tab
              }
            } label: {
              ZStack {
                // The floating blue pill background is now handled by the shared overlay
                // to match the curve geometry.
                
                Image(systemName: tab == .discover ? "star.fill" : "bookmark.fill")
                  .font(.system(size: 20, weight: .bold)) // Bolder matches specific reference
                  .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                  .shadow(
                    color: selectedTab == tab ? .black.opacity(0.4) : .clear,
                    radius: 3, x: 0, y: 3
                  )
                  // Rotation removed as requested
                  // Offset icons to align with the visual center of the curved pill segments
                  // Since pills are trimmed 0.0-0.45 (center 0.225) vs button center 0.25,
                  // we shift icons outwards slightly.
                  .offset(x: tab == .discover ? -16 : 16, y: -12)
              }
              .frame(maxWidth: .infinity)
              .frame(height: 64) // Match bar height
              .contentShape(Rectangle())
            }
          }
        }
        .frame(height: 64)
        .padding(.horizontal, 20)
        .background {
          GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            // Use user's requested Liquid Glass technique:
            // Stroking the path defines the area for the glass effect
            Color.clear
              .glassEffect(
                .regular,
                in: CurvedTabBarGeometry.pathForCurvedTabBar(in: rect)
                  .strokedPath(StrokeStyle(lineWidth: 50, lineCap: .round))
              )
              .overlay(
                 // Blue "Bent Pill" Indicator
                  CurvedTabBarGeometry.pathForCurvedTabBar(in: rect)
                   .trim(
                     from: selectedTab == .discover ? 0.0 : 0.58,
                     to: selectedTab == .discover ? 0.42 : 1.0
                   )
                   .stroke(
                     RadialGradient(
                         colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                         center: .top,
                         startRadius: 0,
                         endRadius: 100
                     ),
                     style: StrokeStyle(lineWidth: 38, lineCap: .round)
                   )
                   .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0) // Soft Glow
                   .overlay(
                       // Rim Light Border around the Pill
                       RimLightPill(
                           trimFrom: selectedTab == .discover ? 0.0 : 0.58,
                           trimTo: selectedTab == .discover ? 0.42 : 1.0
                       )
                       .stroke(Color.white.opacity(0.5), lineWidth: 1)
                   )
              )
              .overlay(
                // White Border Outline
                CurvedTabBarGeometry.pathForCurvedTabBar(in: rect)
                  .strokedPath(StrokeStyle(lineWidth: 50, lineCap: .round))
                  .stroke(Color.white.opacity(0.2), lineWidth: 1)
              )
              .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
          }
        }
        .padding(.horizontal, 100) // Further reduced width as requested
        .padding(.bottom, 0) // Move Tab Bar DOWN (15 -> 0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        // Floating Search Button (Below Tab Bar)
        if !isTabBarHidden {
           Button {
             let impact = UIImpactFeedbackGenerator(style: .light)
             impact.impactOccurred()
             withAnimation(.snappy) {
               isSearchActive = true
             }
           } label: {
             Image(systemName: "magnifyingglass")
               .font(.system(size: 20, weight: .bold))
               .foregroundStyle(.white)
               .padding(14)
               .background {
                  Color.blue.opacity(0.3) // Dark Blue Tint
                    .clipShape(Circle()) // Force tint to be circular
                    .glassEffect(.regular, in: Circle())
                    .overlay(
                        Circle()
                          .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
               }
               // Add a subtle shadow
               .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
           }
            .padding(.bottom, 14) // Move Button UP (12 -> 14)
         }
       
       // Global Search Overlay
       if isSearchActive {
         SearchResultsView(
            isSearchActive: $isSearchActive,
            animation: animation,
            heroNamespace: heroNamespace
         )
         .transition(.opacity)
         .zIndex(50) // Above tab bar
       }
      }
      .preferredColorScheme(.dark)
      .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { hidden in
        withAnimation {
          isTabBarHidden = hidden
        }
      }
    }
  }
}

#Preview {
  if #available(iOS 26.0, *) {
    ContentView()
      .modelContainer(for: [Title.self, UserLibraryItem.self])
  } else {
    Text("Requires iOS 26.0+")
  }
}
