import SwiftUI

struct EpisodeProgressRing: View {
  let watched: Int
  let total: Int
  var size: CGFloat = 36
  var lineWidth: CGFloat = 3

  private var progress: Double {
    guard total > 0 else { return 0 }
    return Double(watched) / Double(total)
  }

  private var isComplete: Bool {
    watched >= total && total > 0
  }

  var body: some View {
    ZStack {
      // Background circle
      Circle()
        .stroke(Color.white.opacity(0.2), lineWidth: lineWidth)

      // Progress arc
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          isComplete ? Color.green : Color.blue,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)

      // Center text
      VStack(spacing: 0) {
        Text("\(watched)")
          .font(.system(size: size * 0.3, weight: .bold))
          .foregroundStyle(isComplete ? .green : .white)

        Rectangle()
          .fill(Color.white.opacity(0.5))
          .frame(width: size * 0.4, height: 1)

        Text("\(total)")
          .font(.system(size: size * 0.25, weight: .medium))
          .foregroundStyle(.gray)
      }
    }
    .frame(width: size, height: size)
  }
}

#Preview {
  HStack(spacing: 20) {
    EpisodeProgressRing(watched: 5, total: 10)
    EpisodeProgressRing(watched: 10, total: 10)
    EpisodeProgressRing(watched: 0, total: 8)
  }
  .padding()
  .background(Color.black)
}
