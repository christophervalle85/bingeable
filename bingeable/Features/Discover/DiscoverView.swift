import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DiscoverViewModel()

    private var isInitialLoading: Bool {
        viewModel.isLoading && viewModel.trending.isEmpty && viewModel.popular.isEmpty
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    heading

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isInitialLoading {
                        heroSkeleton
                        DiscoverShelfSkeletonSection(title: "Trending")
                        DiscoverShelfSkeletonSection(title: "Popular")
                    } else {
                        if let hero = viewModel.heroShow {
                            heroSection(for: hero)
                        }

                        ForEach(viewModel.categorySections) { section in
                            categorySection(section)
                        }

                        if viewModel.isHydratingDetails {
                            hydrationState
                        }
                    }
                }
                .padding(.vertical, 18)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoading, !isInitialLoading {
                    ProgressView()
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(.trailing, 20)
                        .padding(.top, 6)
                }
            }
        }
        .navigationTitle("Discover")
        .animation(.easeInOut(duration: 0.22), value: viewModel.categorySections.map(\.shows.count))
        .animation(.easeInOut(duration: 0.22), value: viewModel.isHydratingDetails)
        .task {
            await viewModel.load(using: appContainer.showRepository)
        }
        .refreshable {
            await viewModel.refresh(using: appContainer.showRepository)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Discover")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryTextColor)

            Text("Hero picks and curated lists by category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private func heroSection(for show: Show) -> some View {
        let isSaved = libraryStore.shelf(for: show.id) != nil
        let heroLabel = show.bingeableState == .ready ? "Ready Now" : "Watch Soon"

        return ZStack(alignment: .topTrailing) {
            NavigationLink {
                ShowDetailView(seedShow: show)
            } label: {
                DiscoverHeroCardView(show: show, headline: heroLabel, isSaved: isSaved)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens show details")
            .accessibilityIdentifier("discover-hero-card")

            DiscoverQuickSaveButton(isSaved: isSaved) {
                toggleSavedState(for: show)
            }
            .padding(14)
            .accessibilityIdentifier("discover-hero-save")
        }
        .padding(.horizontal, 20)
    }

    private func categorySection(_ section: DiscoverViewModel.DiscoverCategorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverSectionHeaderView(title: section.title, subtitle: section.subtitle)
                .padding(.horizontal, 20)

            if section.shows.isEmpty {
                Text(section.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(section.shows) { show in
                            shelfCard(for: show)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discover-section-\(section.id)")
    }

    private func shelfCard(for show: Show) -> some View {
        let isSaved = libraryStore.shelf(for: show.id) != nil

        return ZStack(alignment: .topTrailing) {
            NavigationLink {
                ShowDetailView(seedShow: show)
            } label: {
                DiscoverShelfCardView(show: show, isSaved: isSaved)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens show details")
            .accessibilityIdentifier("discover-card-\(show.id)")

            DiscoverQuickSaveButton(isSaved: isSaved) {
                toggleSavedState(for: show)
            }
            .padding(14)
            .accessibilityIdentifier("discover-save-\(show.id)")
        }
    }

    private var hydrationState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Checking what is ready to binge...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private func toggleSavedState(for show: Show) {
        if libraryStore.shelf(for: show.id) == nil {
            libraryStore.upsert(show: show, shelf: .waiting)
        } else {
            libraryStore.remove(showID: show.id)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Could not refresh Discover")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryTextColor)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await viewModel.refresh(using: appContainer.showRepository)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private var heroSkeleton: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.secondary.opacity(0.16))
            .frame(height: 230)
            .padding(.horizontal, 20)
            .redacted(reason: .placeholder)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.18),
                    Color.indigo.opacity(colorScheme == .dark ? 0.16 : 0.08),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: 120, y: -260)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 210, height: 210)
                .blur(radius: 14)
                .offset(x: -130, y: -120)
        }
    }
}

private struct DiscoverShelfSkeletonSection: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverSectionHeaderView(title: title, subtitle: "")
                .padding(.horizontal, 20)
                .redacted(reason: .placeholder)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 196, height: 310)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .redacted(reason: .placeholder)
    }
}
