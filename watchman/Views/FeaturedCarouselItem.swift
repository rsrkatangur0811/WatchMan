import SwiftUI

struct FeaturedCarouselItem: View {
  let title: Title
  let screenWidth: CGFloat
  let onUpdateColor: (Title) -> Void
  let onSelect: (Title) -> Void
  var namespace: Namespace.ID? = nil
  var sourceID: String? = nil

  var body: some View {
    GeometryReader { proxy in
      FeaturedCardView(title: title)
        .scaleEffect(scaleValue(proxy, in: screenWidth))
        .opacity(opacityValue(proxy, in: screenWidth))
        .rotation3DEffect(
          .degrees(rotationValue(proxy, in: screenWidth)),
          axis: (x: 0, y: 1, z: 0)
        )
        .onAppear {
          // Only update color if this item is currently centered
          let midX = proxy.frame(in: .global).midX
          let screenCenter = screenWidth / 2
          let threshold: CGFloat = 50
          if abs(midX - screenCenter) < threshold {
            onUpdateColor(title)
          }
        }
        .onChange(of: proxy.frame(in: .global).midX) { oldValue, newValue in
          let screenCenter = screenWidth / 2
          let threshold: CGFloat = 50
          if abs(newValue - screenCenter) < threshold {
            onUpdateColor(title)
          }
        }
        .onTapGesture {
          onSelect(title)
        }
        .if(namespace != nil && sourceID != nil) { view in
          view.matchedTransitionSource(id: sourceID!, in: namespace!) { config in
            config.clipShape(RoundedRectangle(cornerRadius: 20))
          }
        }
    }
    .frame(width: 300, height: 400)
  }

  // Helper functions for Carousel Loop
  private func scaleValue(_ proxy: GeometryProxy, in screenWidth: CGFloat) -> CGFloat {
    let midX = proxy.frame(in: .global).midX
    let center = screenWidth / 2
    let distance = abs(center - midX)
    let scale = 1.0 - (distance / screenWidth) * 0.2  // Scale down items as they move away
    return max(0.8, scale)
  }

  private func opacityValue(_ proxy: GeometryProxy, in screenWidth: CGFloat) -> Double {
    let midX = proxy.frame(in: .global).midX
    let center = screenWidth / 2
    let distance = abs(center - midX)
    let opacity = 1.0 - (distance / screenWidth) * 0.5
    return max(0.5, opacity)
  }

  private func rotationValue(_ proxy: GeometryProxy, in screenWidth: CGFloat) -> Double {
    let midX = proxy.frame(in: .global).midX
    let center = screenWidth / 2
    let distance = (midX - center)
    let rotation = Double(distance / screenWidth) * 20  // Rotate slightly
    return rotation
  }
}
