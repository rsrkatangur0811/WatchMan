import SwiftUI

// MARK: - Card Scroll Transition Carousel
// A smooth card scrolling experience with scale, blur, and opacity transitions
// Cards animate in as they enter the viewport using SwiftUI's scrollTransition modifier

/// Individual card view with image, gradient overlay, and text content
struct ScrollTransitionCardView: View {
    let title: Title
    let isExpanded: Bool
    
    @State private var textlessPosterPath: String? = nil
    @State private var logoPath: String? = nil
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            let posterPath = textlessPosterPath ?? title.posterPath
            TMDBImage(path: posterPath, size: .w500) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(minHeight: 200)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
            
            // Gradient Overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                if let logoPath {
                    TMDBImage(path: logoPath, size: .w500) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50, alignment: .leading)
                    } placeholder: {
                        Text(title.name ?? title.title ?? "Unknown Title")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                } else {
                    Text(title.name ?? title.title ?? "Unknown Title")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                
                if let overview = title.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(isExpanded ? 3 : 1)
                }
                
                // Additional metadata row
                HStack(spacing: 12) {
                    if let releaseDate = title.releaseDate, releaseDate.count >= 4 {
                        Text(String(releaseDate.prefix(4)))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if let rating = title.voteAverage {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .task {
            // Fetch textless poster and logo on-demand
            guard let id = title.id else { return }
            let mediaType = title.name != nil ? "tv" : "movie"
            
            async let posterTask = TMDBClient.shared.fetchTextlessPosterPath(id: id, mediaType: mediaType)
            async let logoTask = TMDBClient.shared.fetchLogoPath(id: id, mediaType: mediaType)
            
            let (poster, logo) = await (posterTask, logoTask)
            
            self.textlessPosterPath = poster
            self.logoPath = logo
        }
    }
}

/// Main card scroll transition carousel view
/// Cards scale up, blur, and fade in as they enter the viewport
@available(iOS 18.0, *)
struct CardScrollTransitionView: View {
    let titles: [Title]
    let onSelect: (Title) -> Void
    
    var namespace: Namespace.ID? = nil
    var sourceIDPrefix: String = "cardScroll"
    
    @State private var selectedTitle: Title? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(titles, id: \.stableDisplayID) { title in
                    let sourceID = "\(sourceIDPrefix)_\(title.stableDisplayID)"
                    
                    cardItem(for: title, sourceID: sourceID)
                        .frame(height: selectedTitle == title ? 280 : 220)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                // Toggle expand/collapse on tap
                                selectedTitle = selectedTitle == title ? nil : title
                            }
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            
                            // Longer tap could trigger navigation
                        }
                        .onLongPressGesture(minimumDuration: 0.3) {
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            onSelect(title)
                        }
                        .if(namespace != nil) { view in
                            view.matchedTransitionSource(id: sourceID, in: namespace!) { config in
                                config.clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
    }
    
    /// Creates a card with scroll-based transitions
    /// Cards will scale, blur, and fade as they enter/exit the viewport
    @ViewBuilder
    func cardItem(for title: Title, sourceID: String) -> some View {
        ScrollTransitionCardView(title: title, isExpanded: selectedTitle == title)
            .scrollTransition { content, phase in
                content
                    // Scale effect: cards start at 2x and scale down to normal
                    .scaleEffect(phase.isIdentity ? 1 : 2)
                    // Blur effect: creates depth as cards enter view
                    .blur(radius: phase.isIdentity ? 0 : 50)
                    // Offset: cards slide up into position
                    .offset(y: phase.isIdentity ? 0 : 100)
                    // Opacity: fade in smoothly
                    .opacity(phase.isIdentity ? 1 : 0)
            }
    }
}

// MARK: - Alternative Transition Styles

@available(iOS 18.0, *)
extension CardScrollTransitionView {
    /// Subtle slide-in transition (less dramatic)
    @ViewBuilder
    func subtleTransitionCard(for title: Title, sourceID: String) -> some View {
        ScrollTransitionCardView(title: title, isExpanded: selectedTitle == title)
            .scrollTransition(.animated(.smooth)) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    .offset(x: phase.isIdentity ? 0 : (phase.value < 0 ? -30 : 30))
                    .opacity(phase.isIdentity ? 1 : 0.7)
            }
    }
    
    /// Flip transition effect
    @ViewBuilder
    func flipTransitionCard(for title: Title, sourceID: String) -> some View {
        ScrollTransitionCardView(title: title, isExpanded: selectedTitle == title)
            .scrollTransition(.interactive) { content, phase in
                content
                    .rotation3DEffect(
                        .degrees(phase.isIdentity ? 0 : phase.value * 30),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.5
                    )
                    .offset(y: phase.isIdentity ? 0 : phase.value * 50)
                    .opacity(phase.isIdentity ? 1 : 0.5)
            }
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 18.0, *) {
        CardScrollTransitionView(
            titles: [],
            onSelect: { _ in }
        )
        .preferredColorScheme(.dark)
    } else {
        Text("Requires iOS 18.0+")
    }
}
