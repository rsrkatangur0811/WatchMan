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
  @Namespace private var animation

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        // Main Content
        TabView(selection: $selectedTab) {
          HomeView()
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
                  .rotationEffect(tab == .discover ? .degrees(-17) : .degrees(17))
                  // Offset icons to align with the visual center of the curved pill segments
                  // Since pills are trimmed 0.0-0.45 (center 0.225) vs button center 0.25,
                  // we shift icons outwards slightly.
                  .offset(x: tab == .discover ? -8 : 8, y: 3)
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
                  .strokedPath(StrokeStyle(lineWidth: 64, lineCap: .round))
              )
              .overlay(
                 // Blue "Bent Pill" Indicator
                 CurvedTabBarGeometry.pathForCurvedTabBar(in: rect)
                  .trim(
                    from: selectedTab == .discover ? 0.0 : 0.65,
                    to: selectedTab == .discover ? 0.35 : 1.0
                  )
                  .stroke(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 44, lineCap: .round)
                  )
              )
              .overlay(
                // White Border Outline
                CurvedTabBarGeometry.pathForCurvedTabBar(in: rect)
                  .strokedPath(StrokeStyle(lineWidth: 64, lineCap: .round))
                  .stroke(Color.white.opacity(0.2), lineWidth: 1)
              )
              .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
          }
        }
        .padding(.horizontal, 100) // Further reduced width as requested
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
