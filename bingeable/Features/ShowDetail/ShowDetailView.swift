import SwiftUI

struct ShowDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: ShowDetailViewModel

    init(seedShow: Show) {
        _viewModel = StateObject(wrappedValue: ShowDetailViewModel(seedShow: seedShow))
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    statsSection
                    seasonEpisodesCard
                    providersCard
                    libraryCard

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .navigationTitle(viewModel.show.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await viewModel.load(using: appContainer.showRepository)
        }
    }

    private var heroSection: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height: CGFloat = 420

            ZStack(alignment: .bottomLeading) {
                PosterImageView(
                    posterPath: viewModel.show.posterPath,
                    width: width,
                    height: height
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.2),
                                    .black.opacity(0.58),
                                    .black.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("SERIES")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2), in: Capsule())

                    Text(viewModel.show.name)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .fontWidth(.compressed)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        BingeableBadgeView(state: viewModel.show.bingeableState)

                        if let status = viewModel.show.status {
                            detailChip(
                                text: status.displayName,
                                systemImage: "dot.radiowaves.left.and.right"
                            )
                        }
                    }

                    if !genreLine.isEmpty {
                        Text(genreLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(2)
                    }

                    Text(viewModel.show.overview.isEmpty ? "No overview available." : viewModel.show.overview)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(4)
                }
                .padding(20)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        }
        .frame(height: 420)
    }

    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(stat.title, systemImage: stat.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(stat.value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(detailCardBackground)
                }
            }
        }
    }

    private var seasonEpisodesCard: some View {
        detailCard(title: "Episodes by Season", systemImage: "list.bullet.rectangle.portrait") {
            if releasedSeasons.isEmpty {
                if let airedEpisodeCount = viewModel.show.airedEpisodeCount, airedEpisodeCount > 0 {
                    Text("\(airedEpisodeCount) episodes are currently released, but season-level episode data is unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Season and episode data is not available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Released: \(releasedSeasons.count) \(releasedSeasons.count == 1 ? "season" : "seasons"), \(releasedEpisodeTotal) episodes"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    seasonDropdownButton

                    if let selectedSeason {
                        Text("\(seasonLabel(for: selectedSeason)) • \(seasonMetadata(for: selectedSeason))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isLoadingSeasonEpisodes {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage = viewModel.seasonEpisodesErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if viewModel.seasonEpisodes.isEmpty {
                        Text("No episode data available for this season.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 9) {
                            ForEach(viewModel.seasonEpisodes) { episode in
                                episodeRow(episode)
                            }
                        }
                    }
                }
            }
        }
    }

    private var libraryCard: some View {
        detailCard(title: "Your Library", systemImage: "books.vertical") {
            VStack(alignment: .leading, spacing: 12) {
                if let currentShelf = libraryStore.shelf(for: viewModel.show.id) {
                    Label("Saved in \(currentShelf.title)", systemImage: currentShelf.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Menu("Move") {
                            ForEach(LibraryShelf.allCases) { shelf in
                                Button(shelf.title) {
                                    libraryStore.upsert(show: viewModel.show, shelf: shelf)
                                }
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Remove", role: .destructive) {
                            libraryStore.remove(showID: viewModel.show.id)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Save this show to keep track of where you are.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(LibraryShelf.allCases) { shelf in
                                Button {
                                    libraryStore.upsert(show: viewModel.show, shelf: shelf)
                                } label: {
                                    Label(shelf.title, systemImage: shelf.systemImage)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(tintForShelf(shelf))
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail-library-section")
    }

    private var providersCard: some View {
        detailCard(title: "Streaming On", systemImage: "play.tv") {
            if providers.isEmpty {
                Text("No streaming provider data available for your region.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Available in your region")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: providerColumns, alignment: .leading, spacing: 10) {
                        ForEach(providers) { provider in
                            providerRow(provider)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail-providers-section")
    }

    private var providers: [WatchProvider] {
        viewModel.providers
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))

            content()
        }
        .padding(14)
        .background(detailCardBackground)
    }

    private func episodeRow(_ episode: ShowEpisode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("E\(episode.episodeNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(episode.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let airDate = episode.airDate {
                    Text(DateParsing.mediumDateFormatter.string(from: airDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !episode.overview.isEmpty {
                Text(episode.overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let runtimeMinutes = episode.runtimeMinutes, runtimeMinutes > 0 {
                Text("\(runtimeMinutes) min")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var seasonDropdownButton: some View {
        Menu {
            ForEach(releasedSeasons) { season in
                Button {
                    Task {
                        await viewModel.selectSeason(season.seasonNumber, using: appContainer.showRepository)
                    }
                } label: {
                    if season.seasonNumber == selectedSeason?.seasonNumber {
                        Label(seasonLabel(for: season), systemImage: "checkmark")
                    } else {
                        Text(seasonLabel(for: season))
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(selectedSeason.map(seasonLabel(for:)) ?? "Season 1")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 170, maxWidth: 240, alignment: .leading)
        .accessibilityLabel("Season selector")
    }

    private var providerColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 130), spacing: 10),
            GridItem(.flexible(minimum: 130), spacing: 10)
        ]
    }

    private func providerRow(_ provider: WatchProvider) -> some View {
        HStack(alignment: .center, spacing: 10) {
            providerLogoBadge(provider)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Streaming")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        }
    }

    private func providerLogoBadge(_ provider: WatchProvider) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.36 : 0.08))

            if let logoURL = providerLogoURL(path: provider.logoPath) {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .empty, .failure:
                        fallbackProviderIcon
                    @unknown default:
                        fallbackProviderIcon
                    }
                }
            } else {
                fallbackProviderIcon
            }
        }
        .frame(width: 42, height: 42)
    }

    private var fallbackProviderIcon: some View {
        Image(systemName: "play.rectangle.fill")
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private func detailChip(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.18), in: Capsule())
    }

    private var detailCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding(.top, 2)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var genreLine: String {
        viewModel.show.genres.map(\.name).joined(separator: " • ")
    }

    private var stats: [DetailStat] {
        var result: [DetailStat] = []

        if let ratingText = ratingText {
            result.append(DetailStat(title: "TMDB Rating", value: ratingText, symbol: "star.fill"))
        }

        if let voteCount = viewModel.show.voteCount, voteCount > 0 {
            result.append(
                DetailStat(
                    title: "Votes",
                    value: compactIntegerFormatter.string(from: NSNumber(value: voteCount)) ?? "\(voteCount)",
                    symbol: "person.2.fill"
                )
            )
        }

        if let airedEpisodeCount = viewModel.show.airedEpisodeCount, airedEpisodeCount > 0 {
            result.append(DetailStat(title: "Episodes", value: "\(airedEpisodeCount)", symbol: "film.stack"))
        }

        if releasedEpisodeTotal > 0 {
            result.append(DetailStat(title: "Released", value: "\(releasedEpisodeTotal) eps", symbol: "checkmark.circle.fill"))
        }

        if let status = viewModel.show.status {
            result.append(DetailStat(title: "Status", value: status.displayName, symbol: "dot.radiowaves.left.and.right"))
        }

        if let nextEpisodeAirDate = viewModel.show.nextEpisodeAirDate {
            result.append(
                DetailStat(
                    title: "Next Episode",
                    value: DateParsing.mediumDateFormatter.string(from: nextEpisodeAirDate),
                    symbol: "calendar"
                )
            )
        }

        if result.isEmpty {
            result.append(DetailStat(title: "Status", value: "Details Loading", symbol: "clock"))
        }

        return result
    }

    private var ratingText: String? {
        guard let voteAverage = viewModel.show.voteAverage, voteAverage > 0 else {
            return nil
        }
        return String(format: "%.1f / 10", voteAverage)
    }

    private var releasedSeasons: [ShowSeason] {
        let now = Date()
        return (viewModel.show.seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .filter { season in
                if let airDate = season.airDate {
                    return airDate <= now
                }
                return (season.episodeCount ?? 0) > 0
            }
            .sorted { lhs, rhs in
                lhs.seasonNumber < rhs.seasonNumber
            }
    }

    private var releasedEpisodeTotal: Int {
        releasedSeasons.reduce(0) { partialResult, season in
            partialResult + (season.episodeCount ?? 0)
        }
    }

    private var selectedSeason: ShowSeason? {
        guard !releasedSeasons.isEmpty else {
            return nil
        }

        if let selectedSeasonNumber = viewModel.selectedSeasonNumber,
           let exact = releasedSeasons.first(where: { $0.seasonNumber == selectedSeasonNumber }) {
            return exact
        }

        return releasedSeasons.first
    }

    private func seasonLabel(for season: ShowSeason) -> String {
        if season.name.lowercased().contains("season") {
            return season.name
        }
        return "Season \(season.seasonNumber)"
    }

    private func seasonMetadata(for season: ShowSeason) -> String {
        var segments: [String] = []
        if let episodeCount = season.episodeCount, episodeCount > 0 {
            segments.append("\(episodeCount) eps")
        }
        if let airDate = season.airDate {
            segments.append(DateParsing.mediumDateFormatter.string(from: airDate))
        }
        return segments.isEmpty ? "Release date TBD" : segments.joined(separator: " • ")
    }

    private var compactIntegerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }

    private func providerLogoURL(path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }

        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return AppConfiguration.tmdbImageBaseURL
            .appendingPathComponent("w92")
            .appendingPathComponent(normalizedPath)
    }

    private func tintForShelf(_ shelf: LibraryShelf) -> Color {
        switch shelf {
        case .waiting:
            return .orange
        case .watching:
            return .blue
        case .finished:
            return .green
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
        LinearGradient(
            colors: [
                Color.red.opacity(colorScheme == .dark ? 0.28 : 0.12),
                Color.black.opacity(colorScheme == .dark ? 0.34 : 0.1),
                platformBackgroundColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct DetailStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String
}
