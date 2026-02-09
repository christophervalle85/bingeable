import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var libraryStore: LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = LibraryViewModel()
    @State private var revealedSectionIDs: Set<String> = []
    @State private var hasRevealedInitialSections = false

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            List {
                Section {
                    LibraryHeaderView(summary: viewModel.summary, isHydrating: viewModel.isHydrating)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    LibraryShelfFilterChips(selectedFilter: $viewModel.shelfFilter)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if let hydrationErrorMessage = viewModel.hydrationErrorMessage {
                        hydrationBanner(hydrationErrorMessage)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                if viewModel.sections.isEmpty {
                    Section {
                        emptyStateCard
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier(
                                viewModel.summary.totalCount == 0 ? "library-empty-all" : "library-empty-filtered"
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(viewModel.sections) { section in
                        LibrarySectionView(
                            section: section,
                            isRevealed: revealedSectionIDs.contains(section.id),
                            onMove: { showID, shelf in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                    viewModel.move(
                                        showID: showID,
                                        to: shelf,
                                        using: libraryStore,
                                        repository: appContainer.showRepository
                                    )
                                }
                            },
                            onRemove: { showID in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    viewModel.remove(
                                        showID: showID,
                                        using: libraryStore,
                                        repository: appContainer.showRepository
                                    )
                                }
                            }
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: viewModel.sections.map(\.id))
            .accessibilityIdentifier("library-list")
        }
        .navigationTitle("Library")
        .searchable(text: $viewModel.searchQuery, prompt: "Search saved shows")
        .onAppear {
            libraryStore.refresh()
            syncFromStore()
        }
        .onChange(of: libraryStore.items) { _, _ in
            syncFromStore()
        }
        .onChange(of: viewModel.sections.map(\.id)) { _, sectionIDs in
            revealSectionsIfNeeded(sectionIDs)
        }
    }

    private var emptyStateCard: some View {
        let isCompletelyEmpty = viewModel.summary.totalCount == 0

        return VStack(spacing: 12) {
            Image(systemName: isCompletelyEmpty ? "books.vertical" : "line.3.horizontal.decrease.circle")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(isCompletelyEmpty ? "Your library is empty" : "No matches found")
                .font(.headline)

            Text(isCompletelyEmpty
                 ? "Save shows from Discover or Search to start building your queue."
                 : "Try a different shelf filter or clear your search query.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isCompletelyEmpty ? "library-empty-all" : "library-empty-filtered")
    }

    private func hydrationBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("library-hydration-banner")
    }

    private func syncFromStore() {
        viewModel.load(
            tracked: libraryStore.allTrackedShows(),
            repository: appContainer.showRepository
        )
    }

    private func revealSectionsIfNeeded(_ sectionIDs: [String]) {
        guard !sectionIDs.isEmpty else {
            revealedSectionIDs = []
            return
        }

        if hasRevealedInitialSections {
            withAnimation(.easeInOut(duration: 0.22)) {
                revealedSectionIDs = Set(sectionIDs)
            }
            return
        }

        hasRevealedInitialSections = true
        revealedSectionIDs = []

        for (index, sectionID) in sectionIDs.enumerated() {
            let delay = 0.08 * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    revealedSectionIDs.formUnion([sectionID])
                }
            }
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
                    Color.blue.opacity(colorScheme == .dark ? 0.28 : 0.14),
                    Color.cyan.opacity(colorScheme == .dark ? 0.18 : 0.08),
                    Color.teal.opacity(colorScheme == .dark ? 0.12 : 0.06),
                    platformBackgroundColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.green.opacity(colorScheme == .dark ? 0.1 : 0.06))
                .frame(width: 280, height: 280)
                .blur(radius: 26)
                .offset(x: 130, y: -290)

            Circle()
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.08 : 0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -120, y: -170)
        }
    }
}
