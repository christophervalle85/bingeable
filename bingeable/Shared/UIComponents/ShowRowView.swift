import SwiftUI

struct ShowRowView: View {
    let show: Show

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImageView(posterPath: show.posterPath)

            VStack(alignment: .leading, spacing: 8) {
                Text(show.name)
                    .font(.headline)
                    .lineLimit(2)

                BingeableBadgeView(state: show.bingeableState)

                if !show.overview.isEmpty {
                    Text(show.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
