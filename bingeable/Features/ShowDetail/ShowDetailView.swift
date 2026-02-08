import SwiftUI

struct ShowDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore

    @StateObject private var viewModel: ShowDetailViewModel

    init(seedShow: Show) {
        _viewModel = StateObject(wrappedValue: ShowDetailViewModel(seedShow: seedShow))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadata
                libraryActions
                providersSection

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
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

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterImageView(posterPath: viewModel.show.posterPath, width: 100, height: 150)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.show.name)
                    .font(.title2.weight(.semibold))

                BingeableBadgeView(state: viewModel.show.bingeableState)

                if !viewModel.show.genres.isEmpty {
                    Text(viewModel.show.genres.map(\.name).joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)

            Text(viewModel.show.overview.isEmpty ? "No overview available." : viewModel.show.overview)
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()

            if let status = viewModel.show.status {
                metadataRow(title: "Status", value: status.displayName)
            }

            if let lastAirDate = viewModel.show.lastAirDate {
                metadataRow(title: "Last aired", value: DateParsing.mediumDateFormatter.string(from: lastAirDate))
            }

            if let nextEpisodeAirDate = viewModel.show.nextEpisodeAirDate {
                metadataRow(title: "Next episode", value: DateParsing.mediumDateFormatter.string(from: nextEpisodeAirDate))
            }
        }
    }

    private var libraryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library")
                .font(.headline)

            if let currentShelf = libraryStore.shelf(for: viewModel.show.id) {
                Text("Currently on \(currentShelf.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
                HStack(spacing: 10) {
                    ForEach(LibraryShelf.allCases) { shelf in
                        Button(shelf.title) {
                            libraryStore.upsert(show: viewModel.show, shelf: shelf)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch Providers")
                .font(.headline)

            if providers.isEmpty {
                Text("No streaming provider data available for your region.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(providers) { provider in
                            Text(provider.name)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var providers: [WatchProvider] {
        viewModel.providers
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
