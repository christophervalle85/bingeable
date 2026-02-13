import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var recentSearchStore: RecentSearchStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if viewModel.shouldShowFilters {
                        controlsRow
                    }

                    if viewModel.shouldShowInitialPrompt {
                        introCard
                    }

                    if viewModel.shouldShowRecents {
                        recentsCard
                    }

                    if viewModel.isSearching {
                        loadingCard
                    }

                    if viewModel.shouldShowNoResultsState {
                        noResultsCard
                    }

                    if !viewModel.displayedResults.isEmpty {
                        resultsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .accessibilityIdentifier("search-scroll")
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search shows")
        .task {
            viewModel.loadRecentShows(from: recentSearchStore)
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.handleQueryChange(
                using: appContainer.showRepository,
                recentSearchStore: recentSearchStore
            )
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(SearchViewModel.SearchSortOption.allCases) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        if option == viewModel.sortOption {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                menuPill(
                    title: "Sort: \(viewModel.sortOption.title)",
                    systemImage: "arrow.up.arrow.down"
                )
            }
            .accessibilityIdentifier("search-sort-menu")

            Menu {
                ForEach(viewModel.availableGenres, id: \.self) { genre in
                    Button {
                        viewModel.selectedGenre = genre
                    } label: {
                        if genre == viewModel.selectedGenre {
                            Label(genre, systemImage: "checkmark")
                        } else {
                            Text(genre)
                        }
                    }
                }
            } label: {
                menuPill(
                    title: viewModel.selectedGenre,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .accessibilityIdentifier("search-genre-menu")

            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("search-filter-bar")
    }

    private var introCard: some View {
        infoCard(
            title: "Find your next show",
            subtitle: "Search by title to see ratings, genres, and binge status.",
            systemImage: "magnifyingglass"
        )
        .accessibilityIdentifier("search-empty-initial")
    }

    private var noResultsCard: some View {
        infoCard(
            title: "No results found",
            subtitle: "Try another title or clear your current filters.",
            systemImage: "sparkle.magnifyingglass"
        )
        .accessibilityIdentifier("search-empty-no-results")
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Searching...")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityIdentifier("search-loading-indicator")
    }

    private var recentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Viewed")
                    .font(.headline)

                Spacer(minLength: 0)

                Button("Clear All") {
                    viewModel.clearRecentShows(using: recentSearchStore)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("search-recents-clear")
            }

            ForEach(viewModel.recentShows) { show in
                NavigationLink {
                    ShowDetailView(seedShow: show)
                } label: {
                    recentShowRow(show)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.recordViewedShow(show, using: recentSearchStore)
                })
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-recent-\(show.id)")
            }
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("search-recents-section")
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resultsLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("search-results-count")

            LazyVStack(spacing: 10) {
                ForEach(viewModel.displayedResults) { show in
                    NavigationLink {
                        ShowDetailView(seedShow: show)
                    } label: {
                        SearchResultRow(
                            show: show,
                            shelf: libraryStore.shelf(for: show.id)
                        )
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.recordViewedShow(show, using: recentSearchStore)
                    })
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search-result-\(show.id)")
                }
            }
        }
    }

    private func recentShowRow(_ show: Show) -> some View {
        HStack(spacing: 10) {
            PosterImageView(
                posterPath: show.posterPath,
                width: 38,
                height: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !show.overview.isEmpty {
                    Text(show.overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.45))
        )
    }

    private var resultsLabel: String {
        let visible = viewModel.displayedResults.count
        let total = viewModel.totalResultCount
        if visible == total {
            return "\(visible) result\(visible == 1 ? "" : "s")"
        }

        return "\(visible) of \(total) results"
    }

    private func infoCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding(.top, 2)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("search-error-banner")
    }

    private func menuPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.62))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.24), lineWidth: 1)
            }
    }

    private var platformBackgroundColor: Color {
#if os(iOS)
        return Color(uiColor: .systemBackground)
#elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
#else
        return Color.white
#endif
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(colorScheme == .dark ? 0.24 : 0.12),
                    Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    Color.teal.opacity(colorScheme == .dark ? 0.11 : 0.06),
                    platformBackgroundColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.1 : 0.06))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: 120, y: -300)

            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.09 : 0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -130, y: -150)
        }
    }
}

private struct SearchResultRow: View {
    let show: Show
    let shelf: LibraryShelf?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImageView(
                posterPath: show.posterPath,
                width: 68,
                height: 102
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(show.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if let shelf {
                        Label(shelf.title, systemImage: shelf.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    BingeableBadgeView(state: show.bingeableState)

                    if let rating = ratingText {
                        Label(rating, systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }

                if !genreText.isEmpty {
                    Text(genreText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !show.overview.isEmpty {
                    Text(show.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private var ratingText: String? {
        guard let voteAverage = show.voteAverage else {
            return nil
        }

        let formattedRating = String(format: "%.1f", voteAverage)
        if let voteCount = show.voteCount, voteCount > 0 {
            return "\(formattedRating) (\(formattedVoteCount(voteCount)))"
        }

        return formattedRating
    }

    private var genreText: String {
        let names = show.genres
            .map(\.name)
            .filter { !$0.isEmpty }

        guard !names.isEmpty else {
            return ""
        }

        return names.prefix(3).joined(separator: " • ")
    }

    private func formattedVoteCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }

        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }

        return "\(count)"
    }
}
