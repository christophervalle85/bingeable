import SwiftUI

struct LibraryCompactRow: View {
    let item: LibraryViewModel.LibraryDisplayItem
    let onMove: (LibraryShelf) -> Void
    let onRemove: () -> Void

    var body: some View {
        NavigationLink {
            ShowDetailView(seedShow: item.seedShow)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PosterImageView(posterPath: item.seedShow.posterPath, width: 56, height: 84)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        BingeableBadgeView(state: item.seedShow.bingeableState)

                        Label(item.shelf.title, systemImage: item.shelf.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let nextEpisodeAirDate = item.nextEpisodeAirDate {
                        Text("Next: \(DateParsing.mediumDateFormatter.string(from: nextEpisodeAirDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !item.statusLabel.isEmpty {
                        Text(item.statusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-row-\(item.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            removeAction

            ForEach(LibraryShelf.allCases) { shelf in
                if shelf != item.shelf {
                    Button {
                        onMove(shelf)
                    } label: {
                        Label("Move to \(shelf.title)", systemImage: shelf.systemImage)
                    }
                    .tint(tint(for: shelf))
                }
            }
        }
        .contextMenu {
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

            removeAction
        }
    }

    private var removeAction: some View {
        Button(role: .destructive) {
            onRemove()
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private func tint(for shelf: LibraryShelf) -> Color {
        switch shelf {
        case .waiting:
            return .orange
        case .watching:
            return .blue
        case .finished:
            return .green
        }
    }
}
