import SwiftUI

struct DiscoverHeroCardView: View {
    let show: Show
    let headline: String
    let isSaved: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                PosterImageView(posterPath: show.posterPath, width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.78)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(show.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        BingeableBadgeView(state: show.bingeableState)

                        if isSaved {
                            Label("Saved", systemImage: "bookmark.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hero show, \(show.name), \(show.bingeableState.title), \(isSaved ? "Saved" : "Not saved")")
    }
}
