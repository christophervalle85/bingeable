import SwiftUI
import SwiftData
import Combine

struct DiscoverView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DiscoverViewModel()

    private var isInitialLoading: Bool {
        viewModel.isLoading && viewModel.trending.isEmpty && viewModel.popular.isEmpty
    }

    var body: some View {
        let savedShowIDs = Set(libraryStore.items.map(\.showID))

        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if isInitialLoading {
                        heroSkeleton
                        DiscoverShelfSkeletonSection(title: "Trending")
                        DiscoverShelfSkeletonSection(title: "Popular")
                    } else {
                        if !viewModel.heroShows.isEmpty, AppConfiguration.discoverPreviewHeroEnabled {
                            DiscoverHeroCarouselSection(
                                shows: viewModel.heroShows,
                                savedShowIDs: savedShowIDs,
                                onToggleSaved: { show in
                                    toggleSavedState(for: show)
                                }
                            )
                        }

                        ForEach(viewModel.categorySections) { section in
                            categorySection(
                                section,
                                savedShowIDs: savedShowIDs
                            )
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
        .task {
            guard !AppConfiguration.isRunningInPreviewHost || AppConfiguration.discoverPreviewDataLoadingEnabled else { return }
            await viewModel.load(using: appContainer.showRepository)
        }
        .refreshable {
            guard !AppConfiguration.isRunningInPreviewHost || AppConfiguration.discoverPreviewDataLoadingEnabled else { return }
            await viewModel.refresh(using: appContainer.showRepository)
        }
        .navigationDestination(for: Show.self) { show in
            ShowDetailView(seedShow: show)
        }
    }

    private func categorySection(
        _ section: DiscoverViewModel.DiscoverCategorySection,
        savedShowIDs: Set<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DiscoverSectionHeaderView(title: section.title, subtitle: "")
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
                    LazyHStack(spacing: 10) {
                        ForEach(section.shows) { show in
                            shelfCard(for: show, savedShowIDs: savedShowIDs)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
                .accessibilityIdentifier("discover-rail-\(section.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discover-section-\(section.id)")
    }

    private func shelfCard(for show: Show, savedShowIDs: Set<Int>) -> some View {
        let isSaved = savedShowIDs.contains(show.id)

        return ZStack(alignment: .topTrailing) {
            NavigationLink(value: show) {
                DiscoverShelfCardView(show: show, isSaved: isSaved)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens show details")
            .accessibilityIdentifier("discover-card-\(show.id)")

            DiscoverQuickSaveButton(isSaved: isSaved) {
                toggleSavedState(for: show)
            }
            .padding(10)
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
                    Color.blue.opacity(colorScheme == .dark ? 0.26 : 0.14),
                    Color.cyan.opacity(colorScheme == .dark ? 0.13 : 0.08),
                    Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.06),
                    platformBackgroundColor
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

private struct DiscoverHeroCarouselSection: View {
    @Environment(\.scenePhase) private var scenePhase

    let shows: [Show]
    let savedShowIDs: Set<Int>
    let onToggleSaved: (Show) -> Void

    @State private var heroSelection = 0
    @State private var lastHeroInteraction = Date()
    @State private var heroLoopCorrectionTask: Task<Void, Never>?

    @ViewBuilder
    var body: some View {
        Group {
            if usesStaticPreviewHero {
                previewStaticHero
            } else {
                interactiveHeroCarousel
            }
        }
        .frame(height: heroSectionHeight)
        .accessibilityIdentifier("discover-hero-carousel")
    }

    private var heroSectionHeight: CGFloat { 252 }

    private var interactiveHeroCarousel: some View {
        let carouselShows = carouselShows(from: shows)

        return heroCarouselContainer(for: carouselShows)
            .onChange(of: shows.map(\.id)) { _, ids in
                guard !ids.isEmpty else {
                    heroSelection = initialHeroSelection
                    heroLoopCorrectionTask?.cancel()
                    return
                }

                if ids.count == 1 {
                    heroSelection = initialHeroSelection
                    heroLoopCorrectionTask?.cancel()
                } else if usesLoopedCarousel {
                    if heroSelection <= 0 || heroSelection > ids.count + 1 {
                        heroSelection = 1
                    }
                } else if heroSelection < 0 || heroSelection >= ids.count {
                    heroSelection = 0
                }

                markHeroInteractionIfNeeded()
            }
            .onChange(of: heroSelection) { _, _ in
                markHeroInteractionIfNeeded()

                guard shows.count > 1 else { return }
                guard usesLoopedCarousel else {
                    heroLoopCorrectionTask?.cancel()
                    return
                }

                if heroSelection == 0 {
                    scheduleHeroLoopCorrection(from: 0, to: shows.count)
                } else if heroSelection == shows.count + 1 {
                    scheduleHeroLoopCorrection(from: shows.count + 1, to: 1)
                } else {
                    heroLoopCorrectionTask?.cancel()
                }
            }
            .onDisappear {
                heroLoopCorrectionTask?.cancel()
            }
            .task(id: heroAutoplayTaskID) {
                await runHeroAutoplayLoop()
            }
            .onAppear {
                normalizeSelectionIfNeeded()
            }
    }

    @ViewBuilder
    private var previewStaticHero: some View {
        if let firstShow = shows.first {
            heroSlide(for: firstShow)
                .padding(.horizontal, 20)
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
                .padding(.horizontal, 20)
        }
    }

    private var usesStaticPreviewHero: Bool {
        AppConfiguration.isRunningInPreviewHost && !AppConfiguration.discoverPreviewHeroInteractiveEnabled
    }

    private var usesLoopedCarousel: Bool {
        !AppConfiguration.isRunningInPreviewHost
    }

    private var initialHeroSelection: Int {
        usesLoopedCarousel ? 1 : 0
    }

    private func carouselShows(from shows: [Show]) -> [Show] {
        guard usesLoopedCarousel,
              shows.count > 1,
              let first = shows.first,
              let last = shows.last else {
            return shows
        }

        return [last] + shows + [first]
    }

    @ViewBuilder
    private func heroCarouselContainer(for carouselShows: [Show]) -> some View {
        if usesLoopedCarousel {
            TabView(selection: $heroSelection) {
                ForEach(Array(carouselShows.enumerated()), id: \.offset) { index, show in
                    heroSlide(for: show)
                        .padding(.horizontal, 20)
                        .tag(index)
                }
            }
            .discoverHeroTabStyle()
        } else {
            ZStack {
                if carouselShows.indices.contains(heroSelection) {
                    heroSlide(for: carouselShows[heroSelection])
                        .padding(.horizontal, 20)
                        .id(carouselShows[heroSelection].id)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        guard carouselShows.count > 1 else { return }

                        let threshold: CGFloat = 42
                        let projected = value.predictedEndTranslation.width
                        let drag = value.translation.width
                        var nextSelection = heroSelection

                        if drag < -threshold || projected < -threshold {
                            nextSelection += 1
                        } else if drag > threshold || projected > threshold {
                            nextSelection -= 1
                        }

                        nextSelection = min(max(nextSelection, 0), max(carouselShows.count - 1, 0))
                        guard nextSelection != heroSelection else { return }

                        withAnimation(.easeInOut(duration: 0.24)) {
                            heroSelection = nextSelection
                        }
                    }
            )
        }
    }

    private func normalizeSelectionIfNeeded() {
        guard !shows.isEmpty else {
            heroSelection = initialHeroSelection
            return
        }

        if shows.count == 1 {
            heroSelection = initialHeroSelection
            return
        }

        if usesLoopedCarousel {
            if heroSelection <= 0 || heroSelection > shows.count + 1 {
                heroSelection = 1
            }
        } else if heroSelection < 0 || heroSelection >= shows.count {
            heroSelection = 0
        }
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

    private var shouldRunHeroAutoplay: Bool {
        AppConfiguration.discoverHeroAutoplayEnabled
            && shows.count > 1
            && scenePhase == .active
    }

    private struct HeroAutoplayTaskID: Hashable {
        let showIDs: [Int]
        let shouldRun: Bool
        let intervalNanoseconds: UInt64
        let idleThresholdSeconds: TimeInterval
    }

    private var heroAutoplayTaskID: HeroAutoplayTaskID {
        HeroAutoplayTaskID(
            showIDs: shows.map(\.id),
            shouldRun: shouldRunHeroAutoplay,
            intervalNanoseconds: heroAutoplayIntervalNanoseconds,
            idleThresholdSeconds: AppConfiguration.discoverHeroAutoplayIdleThresholdSeconds
        )
    }

    private var heroAutoplayIntervalNanoseconds: UInt64 {
        let seconds = max(0.5, AppConfiguration.discoverHeroAutoplayIntervalSeconds)
        return UInt64(seconds * 1_000_000_000)
    }

    private var heroAutoplayAnimation: Animation {
        if AppConfiguration.isRunningInPreviewHost {
            return .easeInOut(duration: 0.18)
        }

        return .smooth(duration: AppConfiguration.discoverHeroAutoplayAnimationDurationSeconds, extraBounce: 0.02)
    }

    @MainActor
    private func runHeroAutoplayLoop() async {
        guard shouldRunHeroAutoplay else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: heroAutoplayIntervalNanoseconds)
            guard !Task.isCancelled else { return }
            guard shouldRunHeroAutoplay else { continue }
            guard Date().timeIntervalSince(lastHeroInteraction) >= AppConfiguration.discoverHeroAutoplayIdleThresholdSeconds else {
                continue
            }

            withAnimation(heroAutoplayAnimation) {
                if usesLoopedCarousel {
                    heroSelection += 1
                } else {
                    heroSelection = (heroSelection + 1) % shows.count
                }
            }
        }
    }

    private func markHeroInteractionIfNeeded() {
        guard AppConfiguration.discoverHeroAutoplayEnabled else { return }
        lastHeroInteraction = Date()
    }

    @ViewBuilder
    private func heroSlide(for show: Show) -> some View {
        let heroLabel = show.bingeableState == .ready ? "Ready Now" : "Watch Soon"
        let saved = savedShowIDs.contains(show.id)

        if AppConfiguration.isRunningInPreviewHost {
            DiscoverHeroCardView(show: show, headline: heroLabel, isSaved: saved)
                .accessibilityIdentifier("discover-hero-card")
        } else {
            ZStack(alignment: .topTrailing) {
                NavigationLink(value: show) {
                    DiscoverHeroCardView(show: show, headline: heroLabel, isSaved: saved)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens show details")
                .accessibilityIdentifier("discover-hero-card")

                DiscoverQuickSaveButton(isSaved: saved) {
                    onToggleSaved(show)
                }
                .padding(14)
                .accessibilityIdentifier("discover-hero-save")
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func discoverHeroTabStyle() -> some View {
#if os(iOS)
        self.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
#else
        self
#endif
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
                LazyHStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 132, height: 198)
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

#Preview("Discover Hero Canvas") {
    DiscoverHeroPreviewHarness()
}

#Preview("Discover In App Shell") {
    DiscoverInAppShellPreviewRoot()
}

@MainActor
private final class DiscoverInAppShellPreviewDependencies: ObservableObject {
    let appContainer: AppContainer
    let modelContainer: ModelContainer
    let libraryStore: LibraryStore

    init() {
        self.appContainer = AppContainer()
        self.appContainer.sessionManager.continueAsGuest()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.modelContainer = try! ModelContainer(for: TrackedShowEntity.self, configurations: config)
        self.libraryStore = LibraryStore(context: modelContainer.mainContext)
    }
}

private struct DiscoverInAppShellPreviewRoot: View {
    @StateObject private var deps = DiscoverInAppShellPreviewDependencies()

    var body: some View {
        NavigationStack {
            DiscoverView()
        }
            .environmentObject(deps.appContainer)
            .environmentObject(deps.appContainer.sessionManager)
            .environmentObject(deps.libraryStore)
            .modelContainer(deps.modelContainer)
    }
}

private struct DiscoverHeroPreviewHarness: View {
    @State private var savedShowIDs: Set<Int> = [1396, 66732]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.9),
                    Color.indigo.opacity(0.42),
                    Color.blue.opacity(0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            DiscoverHeroCarouselSection(
                shows: heroFixtures,
                savedShowIDs: savedShowIDs,
                onToggleSaved: { show in
                    if savedShowIDs.contains(show.id) {
                        savedShowIDs.remove(show.id)
                    } else {
                        savedShowIDs.insert(show.id)
                    }
                }
            )
            .padding(.vertical, 22)
        }
    }

    private var heroFixtures: [Show] {
        [
            Show(
                id: 1396,
                name: "Breaking Bad",
                posterPath: nil,
                overview: "A chemistry teacher turns to crime to secure his family's future.",
                genres: [Genre(id: 18, name: "Drama")],
                status: .ended,
                lastAirDate: DateParsing.parseTMDBDate("2013-09-29"),
                nextEpisodeAirDate: nil,
                airedEpisodeCount: 62
            ),
            Show(
                id: 66732,
                name: "Stranger Things",
                posterPath: nil,
                overview: "A group of kids uncover supernatural mysteries in their small town.",
                genres: [Genre(id: 18, name: "Drama")],
                status: .returningSeries,
                lastAirDate: DateParsing.parseTMDBDate("2022-07-01"),
                nextEpisodeAirDate: DateParsing.parseTMDBDate("2026-10-09"),
                airedEpisodeCount: 34
            ),
            Show(
                id: 94997,
                name: "House of the Dragon",
                posterPath: nil,
                overview: "The Targaryen dynasty is at the absolute apex of its power.",
                genres: [Genre(id: 10765, name: "Sci-Fi & Fantasy")],
                status: .returningSeries,
                lastAirDate: DateParsing.parseTMDBDate("2024-08-04"),
                nextEpisodeAirDate: DateParsing.parseTMDBDate("2026-06-14"),
                airedEpisodeCount: 18
            ),
            Show(
                id: 1429,
                name: "Attack on Titan",
                posterPath: nil,
                overview: "Humanity fights for survival behind walls against giant Titans.",
                genres: [Genre(id: 16, name: "Animation")],
                status: .ended,
                lastAirDate: DateParsing.parseTMDBDate("2023-11-04"),
                nextEpisodeAirDate: nil,
                airedEpisodeCount: 94
            )
        ]
    }
}
