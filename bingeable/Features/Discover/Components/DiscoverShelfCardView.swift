import SwiftUI

struct DiscoverShelfCardView: View {
    let show: Show
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                PosterImageView(posterPath: show.posterPath, width: 176, height: 248)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7), .black.opacity(0.86)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(show.name.uppercased())
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    BingeableBadgeView(state: show.bingeableState)
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }

            HStack(spacing: 6) {
                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.yellow)
                }

                Text(show.status?.displayName ?? "Series")
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(width: 176, alignment: .leading)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(show.name), \(show.bingeableState.title), \(isSaved ? "Saved" : "Not saved")")
    }
}
