import SwiftUI

struct FeaturedCarouselItem: View {
  let title: Title
  let screenWidth: CGFloat
  let onUpdateColor: (Title) -> Void
  let onSelect: (Title) -> Void
  var namespace: Namespace.ID? = nil
  var sourceID: String? = nil
  
  @State private var textlessPosterPath: String? = nil
  @State private var logoPath: String? = nil

  var body: some View {
    GeometryReader { proxy in
      FeaturedCardView(
        title: title, 
        textlessPosterPath: textlessPosterPath,
        logoPath: logoPath
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
    .frame(width: 300, height: 450)
    .task {
      // Fetch visual assets on-demand
      guard let id = title.id else { return }
      let mediaType = title.name != nil ? "tv" : "movie"
      
      // Parallel fetch
      async let poster = TMDBClient.shared.fetchTextlessPosterPath(id: id, mediaType: mediaType)
      async let logo = TMDBClient.shared.fetchLogoPath(id: id, mediaType: mediaType)
      
      textlessPosterPath = await poster
      logoPath = await logo
    }
  }
}
