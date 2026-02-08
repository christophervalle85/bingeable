import SwiftUI

struct DiscoverShelfCardView: View {
    let show: Show
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                PosterImageView(posterPath: show.posterPath, width: 180, height: 252)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.76)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(show.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    BingeableBadgeView(state: show.bingeableState)
                }
                .padding(10)
            }

            if isSaved {
                Label("Saved", systemImage: "bookmark.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: 204, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(show.name), \(show.bingeableState.title), \(isSaved ? "Saved" : "Not saved")")
    }
}
