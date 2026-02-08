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
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    metadataCard
                    overviewCard
                    libraryCard
                    providersCard

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }
                }
                .padding(16)
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

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterImageView(posterPath: viewModel.show.posterPath, width: 104, height: 156)

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.show.name)
                    .font(.title3.weight(.bold))

                BingeableBadgeView(state: viewModel.show.bingeableState)

                if !viewModel.show.genres.isEmpty {
                    Text(viewModel.show.genres.map(\.name).joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(detailCardBackground)
    }

    private var metadataCard: some View {
        detailCard(title: "At a glance", systemImage: "rectangle.stack.person.crop") {
            VStack(spacing: 12) {
                if let status = viewModel.show.status {
                    metadataRow(title: "Status", value: status.displayName)
                }

                if let lastAirDate = viewModel.show.lastAirDate {
                    metadataRow(title: "Last aired", value: DateParsing.mediumDateFormatter.string(from: lastAirDate))
                }

                if let nextEpisodeAirDate = viewModel.show.nextEpisodeAirDate {
                    metadataRow(title: "Next episode", value: DateParsing.mediumDateFormatter.string(from: nextEpisodeAirDate))
                }

                if viewModel.show.status == nil,
                    viewModel.show.lastAirDate == nil,
                    viewModel.show.nextEpisodeAirDate == nil {
                    Text("No metadata available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var overviewCard: some View {
        detailCard(title: "Overview", systemImage: "text.alignleft") {
            Text(viewModel.show.overview.isEmpty ? "No overview available." : viewModel.show.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var libraryCard: some View {
        detailCard(title: "Library", systemImage: "books.vertical") {
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
        detailCard(title: "Watch providers", systemImage: "play.tv") {
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
                                .padding(.vertical, 7)
                                .background(.thinMaterial, in: Capsule())
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
                .font(.headline)

            content()
        }
        .padding(14)
        .background(detailCardBackground)
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

    private var background: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12),
                Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.06),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
