import SwiftUI
import UIKit

extension View {
  /// Applies the given transform if the given condition evaluates to `true`.
  /// - Parameters:
  ///   - condition: The condition to evaluate.
  ///   - transform: The transform to apply to the source `View`.
  /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
  @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content)
    -> some View
  {
    if condition {
      transform(self)
    } else {
      self
    }
  }

  // MARK: - Glass Effect Compatibility
  @ViewBuilder
  func glassedEffect<S: Shape>(
    in shape: S,
    isEnabled: Bool = true
  ) -> some View {
    if !isEnabled {
      self
    } else if #available(iOS 26.0, *) {
      self.glassEffect(.regular, in: shape)
    } else {
      self
        .background(.ultraThinMaterial, in: shape)
    }
  }

  func iconPillControl(
    minWidth: CGFloat = 54,
    height: CGFloat = 40,
    fillOpacity: Double = 0.18
  ) -> some View {
    self
      .foregroundStyle(.white)
      .frame(minWidth: minWidth)
      .frame(height: height)
      .background {
        Capsule()
          .fill(.white.opacity(fillOpacity))
      }
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .strokeBorder(.white.opacity(0.22), lineWidth: 1)
      }
  }

  func liquidGlassIconPill(
    minWidth: CGFloat = 58,
    height: CGFloat = 42,
    fillOpacity: Double = 0.18
  ) -> some View {
    self
      .foregroundStyle(.white)
      .frame(minWidth: minWidth)
      .frame(height: height)
      .background {
        Capsule()
          .fill(.black.opacity(fillOpacity))
          .glassedEffect(in: Capsule())
      }
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .strokeBorder(.white.opacity(0.16), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
  }

  func appNavigationBackButton() -> some View {
    modifier(AppNavigationBackButtonModifier())
  }

  func enablesInteractivePopGesture() -> some View {
    background(InteractivePopGestureEnabler())
  }

  @ViewBuilder
  func scrollTargetBehaviorCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.scrollTargetBehavior(.viewAligned)
    } else {
      self
    }
  }

  @ViewBuilder
  func scrollTargetLayoutCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.scrollTargetLayout()
    } else {
      self
    }
  }

  @ViewBuilder
  func scrollEdgeEffectHiddenCompat(_ hidden: Bool = true) -> some View {
    if #available(iOS 26.0, *) {
      self.scrollEdgeEffectHidden(hidden)
    } else {
      self
    }
  }

  @ViewBuilder
  func scrollEdgeEffectSoftCompat(for edges: Edge.Set = .all) -> some View {
    if #available(iOS 26.0, *) {
      self.scrollEdgeEffectStyle(.soft, for: edges)
    } else {
      self
    }
  }
}

private struct AppNavigationBackButtonModifier: ViewModifier {
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content
      .navigationBarBackButtonHidden(true)
      .enablesInteractivePopGesture()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.white)
              .frame(minWidth: 58)
              .frame(height: 42)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Back")
        }
      }
  }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController {
    PopGestureHostingController()
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    Self.configurePopGesture(from: uiViewController)

    DispatchQueue.main.async {
      Self.configurePopGesture(from: uiViewController)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      Self.configurePopGesture(from: uiViewController)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      Self.configurePopGesture(from: uiViewController)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      Self.configurePopGesture(from: uiViewController)
    }
  }

  private static func configurePopGesture(from viewController: UIViewController) {
    guard let navigationController = findNavigationController(from: viewController) else { return }
    let popGesture = navigationController.interactivePopGestureRecognizer
    popGesture?.isEnabled = navigationController.viewControllers.count > 1
    popGesture?.delegate = nil
  }

  private static func findNavigationController(from viewController: UIViewController) -> UINavigationController? {
    if let navigationController = viewController.navigationController {
      return navigationController
    }

    var parent = viewController.parent
    while let current = parent {
      if let navigationController = current as? UINavigationController {
        return navigationController
      }
      if let navigationController = current.navigationController {
        return navigationController
      }
      parent = current.parent
    }

    if let root = viewController.view.window?.rootViewController {
      return findNavigationController(in: root)
    }

    return nil
  }

  private static func findNavigationController(in viewController: UIViewController) -> UINavigationController? {
    if let navigationController = viewController as? UINavigationController {
      return navigationController
    }

    for child in viewController.children {
      if let navigationController = findNavigationController(in: child) {
        return navigationController
      }
    }

    if let presented = viewController.presentedViewController {
      return findNavigationController(in: presented)
    }

    return nil
  }

  private final class PopGestureHostingController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      InteractivePopGestureEnabler.configurePopGesture(from: self)
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      InteractivePopGestureEnabler.configurePopGesture(from: self)
    }
  }
}

struct CompatibleScrollGeometry {
  var contentOffset: CGPoint
  var contentInsets: EdgeInsets
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

extension View {
	  func compatibleOnScrollGeometryChange<T: Equatable>(
	    for type: T.Type,
	    _ transform: @escaping (CompatibleScrollGeometry) -> T,
	    action: @escaping (T, T) -> Void
	  ) -> some View {
	    if #available(iOS 18.0, *) {
	      return self.onScrollGeometryChange(for: type) { geometry in
	        let compatibleGeometry = CompatibleScrollGeometry(
	          contentOffset: geometry.contentOffset,
	          contentInsets: geometry.contentInsets
	        )
	        return transform(compatibleGeometry)
	      } action: { oldValue, newValue in
	        action(oldValue, newValue)
	      }
	    } else {
	      return modifier(CompatibleScrollGeometryModifier(transform: transform, action: action))
	    }
	  }
	}

private struct CompatibleScrollGeometryModifier<T: Equatable>: ViewModifier {
  let transform: (CompatibleScrollGeometry) -> T
  let action: (T, T) -> Void
  @State private var previousValue: T?

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear.preference(
            key: ScrollOffsetPreferenceKey.self,
            value: -proxy.frame(in: .global).minY
          )
        }
      )
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
        let geometry = CompatibleScrollGeometry(
          contentOffset: CGPoint(x: 0, y: offset),
          contentInsets: EdgeInsets()
        )
        let newValue = transform(geometry)
        let oldValue = previousValue ?? newValue
        if oldValue != newValue {
          action(oldValue, newValue)
        }
        previousValue = newValue
      }
  }
}

// MARK: - Screen Corner Radius Helper

extension UIScreen {
  /// Returns the corner radius of the device's screen.
  static var screenCornerRadius: CGFloat {
    switch UIDevice.current.userInterfaceIdiom {
    case .pad:
      return 24
    case .phone:
      return 47
    default:
      return 20
    }
  }
}
