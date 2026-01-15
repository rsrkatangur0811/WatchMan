import SwiftData
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }
}

@main
struct WatchmanApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    FontLoader.registerFonts()

    // Configure Navigation Bar Appearance
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont(name: "NetflixSans-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .bold),
    ]
    appearance.largeTitleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont(name: "NetflixSans-Bold", size: 34) ?? .systemFont(ofSize: 34, weight: .bold),
    ]

    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance

    // Configure Segmented Control Appearance
    let segmentedAppearance = UISegmentedControl.appearance()
    segmentedAppearance.setTitleTextAttributes(
      [
        .foregroundColor: UIColor.white,
        .font: UIFont(name: "NetflixSans-Medium", size: 13)
          ?? .systemFont(ofSize: 13, weight: .medium),
      ], for: .normal)
    segmentedAppearance.setTitleTextAttributes(
      [
        .foregroundColor: UIColor.black,
        .font: UIFont(name: "NetflixSans-Bold", size: 13) ?? .systemFont(ofSize: 13, weight: .bold),
      ], for: .selected)
  }

  var body: some Scene {
    WindowGroup {
      if #available(iOS 26.0, *) {
        ContentView()
      } else {
        Text("Requires iOS 26.0+")
          .font(.largeTitle)
      }
    }
    .modelContainer(for: [Title.self, UserLibraryItem.self, WatchedEpisode.self])
  }
}
