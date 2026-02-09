import SwiftUI

struct DiscoverFilterChipsView: View {
    @Binding var readyToBingeOnly: Bool
    @Binding var inLibraryOnly: Bool
    @Binding var sortMode: DiscoverViewModel.DiscoverSortMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    title: "Ready",
                    systemImage: "checkmark.circle.fill",
                    isSelected: readyToBingeOnly,
                    identifier: "discover-chip-ready"
                ) {
                    readyToBingeOnly.toggle()
                }

                filterChip(
                    title: "In Library",
                    systemImage: "bookmark.fill",
                    isSelected: inLibraryOnly,
                    identifier: "discover-chip-library"
                ) {
                    inLibraryOnly.toggle()
                }

                Menu {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(DiscoverViewModel.DiscoverSortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort: \(sortMode.shortTitle)")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.14))
                    }
                }
                .accessibilityIdentifier("discover-sort-menu")
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.95) : Color.secondary.opacity(0.14))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "On" : "Off")
    }
}
