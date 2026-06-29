import SwiftUI

struct FilterPillBar: View {
  @Binding var isMovies: Bool
  var showGlass: Bool = false
  @Namespace private var animation

  private enum FilterOption: String, CaseIterable {
    case movies = "Movies"
    case shows = "Shows"

    var icon: String {
      switch self {
      case .movies: return "film"
      case .shows: return "play.tv"
      }
    }
  }

  private var selectedOption: FilterOption {
    isMovies ? .movies : .shows
  }

  var body: some View {
    // Fixed-width container without scrolling
    HStack(spacing: 0) {
      ForEach(FilterOption.allCases, id: \.self) { option in
        Button {
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isMovies = (option == .movies)
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: option.icon)
              .font(.system(size: 16, weight: .medium))
            Text(option.rawValue)
              .font(.netflixSans(.medium, size: 15))
          }
          .foregroundStyle(selectedOption == option ? .white : .white.opacity(0.7))
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
	          .background {
	            if selectedOption == option {
	              Capsule()
	                .fill(.clear)
	                .glassedEffect(in: Capsule())
	                .overlay {
	                  Capsule()
	                    .fill(Color.white.opacity(0.15))
	                }
	                .matchedGeometryEffect(id: "filterPill", in: animation)
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
	        .glassedEffect(in: Capsule())
	        .overlay {
	          ZStack {
	            Capsule()
	              .fill(Color.black.opacity(showGlass ? 0.08 : 0.22))
	            Capsule()
	              .strokeBorder(Color.white.opacity(showGlass ? 0.24 : 0.18), lineWidth: 1)
	          }
	        }
	    }
    .clipShape(Capsule())  // Key: Clips overflow to capsule shape
    .animation(.easeInOut(duration: 0.2), value: showGlass)
  }
}
