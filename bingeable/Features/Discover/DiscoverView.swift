import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var heroSelection = 1
    @State private var lastHeroInteraction = Date()
    @State private var heroLoopCorrectionTask: Task<Void, Never>?

    private var isInitialLoading: Bool {
        viewModel.isLoading && viewModel.trending.isEmpty && viewModel.popular.isEmpty
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    heading

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isInitialLoading {
                        heroSkeleton
                        DiscoverShelfSkeletonSection(title: "Trending")
                        DiscoverShelfSkeletonSection(title: "Popular")
                    } else {
                        if !viewModel.heroShows.isEmpty {
                            heroCarouselSection(shows: viewModel.heroShows)
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
            .scrollIndicators(.hidden)
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
        .animation(.easeInOut(duration: 0.22), value: viewModel.heroShows.map(\.id))
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

            Text("Swipe hero picks, then dive into curated rails.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private func heroCarouselSection(shows: [Show]) -> some View {
        let loopedShows = loopedHeroShows(from: shows)

        return TabView(selection: $heroSelection) {
            ForEach(Array(loopedShows.enumerated()), id: \.offset) { index, show in
                heroSlide(for: show)
                    .padding(.horizontal, 20)
                    .tag(indexForLoopedHero(at: index, realCount: shows.count))
            }
        }
        .frame(height: 252)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .accessibilityIdentifier("discover-hero-carousel")
        .onChange(of: shows.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                heroSelection = 1
                heroLoopCorrectionTask?.cancel()
                return
            }

            if ids.count == 1 {
                heroSelection = 1
                heroLoopCorrectionTask?.cancel()
            } else if heroSelection <= 0 || heroSelection > ids.count + 1 {
                heroSelection = 1
            }
            lastHeroInteraction = Date()
        }
        .onChange(of: heroSelection) { _, newValue in
            lastHeroInteraction = Date()

            guard shows.count > 1 else { return }

            if newValue == 0 {
                scheduleHeroLoopCorrection(from: 0, to: shows.count)
            } else if newValue == shows.count + 1 {
                scheduleHeroLoopCorrection(from: shows.count + 1, to: 1)
            } else {
                heroLoopCorrectionTask?.cancel()
            }
        }
        .task(id: shows.map(\.id)) {
            guard shows.count > 1 else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                guard Date().timeIntervalSince(lastHeroInteraction) >= 6 else { continue }

                await MainActor.run {
                    withAnimation(.smooth(duration: 0.95, extraBounce: 0.02)) {
                        heroSelection += 1
                    }
                }
            }
        }
        .onDisappear {
            heroLoopCorrectionTask?.cancel()
        }
    }

    private func loopedHeroShows(from shows: [Show]) -> [Show] {
        guard shows.count > 1, let first = shows.first, let last = shows.last else {
            return shows
        }

        return [last] + shows + [first]
    }

    private func indexForLoopedHero(at loopedIndex: Int, realCount: Int) -> Int {
        guard realCount > 1 else { return 1 }

        return loopedIndex
    }

    private func scheduleHeroLoopCorrection(from edgeIndex: Int, to targetIndex: Int) {
        heroLoopCorrectionTask?.cancel()
        heroLoopCorrectionTask = Task { @MainActor in
            // Let the swipe animation complete first, then silently rebase.
            try? await Task.sleep(nanoseconds: 920_000_000)
            guard !Task.isCancelled else { return }
            guard heroSelection == edgeIndex else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                heroSelection = targetIndex
            }
        }
    }

    private func heroSlide(for show: Show) -> some View {
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
    }

    private func categorySection(_ section: DiscoverViewModel.DiscoverCategorySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.secondary.opacity(0.16))
            .frame(height: 248)
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
                    Color.blue.opacity(colorScheme == .dark ? 0.26 : 0.14),
                    Color.cyan.opacity(colorScheme == .dark ? 0.13 : 0.08),
                    Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.06),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.teal.opacity(colorScheme == .dark ? 0.1 : 0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 30)
                .offset(x: 140, y: -320)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 210, height: 210)
                .blur(radius: 22)
                .offset(x: -140, y: -160)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
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
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 176, height: 248)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
