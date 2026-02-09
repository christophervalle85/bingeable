import SwiftUI

struct LibraryFeatureCard: View {
    let item: LibraryViewModel.LibraryDisplayItem
    let onMove: (LibraryShelf) -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ShowDetailView(seedShow: item.seedShow)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    PosterImageView(posterPath: item.seedShow.posterPath, width: 112, height: 168)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.displayName.uppercased())
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .fontWidth(.condensed)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            BingeableBadgeView(state: item.seedShow.bingeableState)

                            Label(item.shelf.title, systemImage: item.shelf.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if let nextEpisodeAirDate = item.nextEpisodeAirDate {
                            Label(
                                "Next episode \(DateParsing.mediumDateFormatter.string(from: nextEpisodeAirDate))",
                                systemImage: "calendar"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        } else {
                            Text(item.statusLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if !item.overview.isEmpty {
                            Text(item.overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library-feature-\(item.id)")

            Menu {
                managementActions()
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.92), .black.opacity(0.5))
                    .padding(10)
            }
            .accessibilityIdentifier("library-overflow-\(item.id)")
        }
        .contextMenu {
            managementActions()
        }
    }

    @ViewBuilder
    private func managementActions() -> some View {
        ForEach(LibraryShelf.allCases) { shelf in
            if shelf != item.shelf {
                Button {
                    onMove(shelf)
                } label: {
                    Label("Move to \(shelf.title)", systemImage: shelf.systemImage)
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            onRemove()
        } label: {
            Label("Remove from Library", systemImage: "trash")
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
    }
}
