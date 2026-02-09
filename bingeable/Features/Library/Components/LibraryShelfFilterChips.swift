import SwiftUI

struct LibraryShelfFilterChips: View {
    @Binding var selectedFilter: LibraryViewModel.LibraryShelfFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryViewModel.LibraryShelfFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("library-filters")
    }

    private func filterChip(for filter: LibraryViewModel.LibraryShelfFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                Text(filter.title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.9) : Color.secondary.opacity(0.14))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library-filter-\(filter.rawValue)")
        .accessibilityValue(isSelected ? "On" : "Off")
    }
}
