import SwiftUI

struct LibrarySectionView: View {
    let section: LibraryViewModel.LibrarySection
    let isRevealed: Bool
    let onMove: (Int, LibraryShelf) -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        Section {
            if let featuredItem = section.items.first {
                LibraryFeatureCard(
                    item: featuredItem,
                    onMove: { shelf in
                        onMove(featuredItem.id, shelf)
                    },
                    onRemove: {
                        onRemove(featuredItem.id)
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library-feature-\(featuredItem.id)")
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(Array(section.items.dropFirst())) { item in
                LibraryCompactRow(
                    item: item,
                    onMove: { shelf in
                        onMove(item.id, shelf)
                    },
                    onRemove: {
                        onRemove(item.id)
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library-row-\(item.id)")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(rowBackground)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Label(section.title, systemImage: section.systemImage)
                    .font(.system(.title3, design: .serif).weight(.heavy))
                    .fontWidth(.condensed)
                    .foregroundStyle(.primary)

                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
            .padding(.horizontal, 2)
        }
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 10)
        .accessibilityIdentifier("library-section-\(section.id)")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}
