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
                            colors: [
                                .black.opacity(0.12),
                                .black.opacity(0.45),
                                .black.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(headline.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.94))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.16), in: Capsule())

                        if let genre = show.genres.first?.name {
                            Text(genre.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }

                    Text(show.name.uppercased())
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !show.overview.isEmpty {
                        Text(show.overview)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        BingeableBadgeView(state: show.bingeableState)

                        if isSaved {
                            Label("Saved", systemImage: "bookmark.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(18)
            }
        }
        .frame(height: 248)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hero show, \(show.name), \(show.bingeableState.title), \(isSaved ? "Saved" : "Not saved")")
    }
}
