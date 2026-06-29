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
      if let startupError = APIConfig.startupError {
        ConfigurationErrorView(error: startupError)
      } else {
        ContentView()
      }
    }
    .modelContainer(for: [UserLibraryItem.self, WatchedEpisode.self])
  }
}

private struct ConfigurationErrorView: View {
  let error: APIConfigError

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(.yellow)
      Text("Configuration Required")
        .font(.netflixSans(.bold, size: 26))
        .foregroundStyle(.white)
      Text(error.localizedDescription)
        .font(.netflixSans(.medium, size: 15))
        .foregroundStyle(.white.opacity(0.75))
        .multilineTextAlignment(.center)
      Text("Add valid API keys through Config.xcconfig or launch environment variables.")
        .font(.netflixSans(.light, size: 13))
        .foregroundStyle(.white.opacity(0.55))
        .multilineTextAlignment(.center)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
  }
}
