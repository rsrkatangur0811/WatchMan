import SwiftUI

struct SectionHeaderView: View {
  let title: String
  let subtitle: String
  var onTap: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
          .font(.netflixSans(.bold, size: 22))
          .foregroundStyle(.white)

        Image(systemName: "chevron.right")
          .foregroundStyle(.gray)
          .font(.netflixSans(.medium, size: 12))
      }

      Text(subtitle)
        .font(.netflixSans(.medium, size: 15))
        .foregroundStyle(.gray)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .padding(.bottom, 15)
    .onTapGesture {
      onTap?()
    }
  }
}

#Preview {
  SectionHeaderView(title: "Featured Movies", subtitle: "Popular and trending movies")
    .background(Color.black)
}
