import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.trending.isEmpty, viewModel.popular.isEmpty {
                ProgressView("Loading shows...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("Discover")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle("Ready", isOn: $viewModel.readyToBingeOnly)
                    .toggleStyle(.switch)
            }
        }
        .task {
            await viewModel.load(using: appContainer.showRepository)
        }
        .refreshable {
            await viewModel.refresh(using: appContainer.showRepository)
        }
    }

    private var content: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if viewModel.visibleTrending.isEmpty, viewModel.visiblePopular.isEmpty {
                EmptyStateView(
                    title: "No shows found",
                    message: "Try refreshing, or disable the Ready filter.",
                    systemImage: "tv"
                )
                .listRowBackground(Color.clear)
            } else {
                if !viewModel.visibleTrending.isEmpty {
                    Section("Trending") {
                        ForEach(viewModel.visibleTrending) { show in
                            NavigationLink {
                                ShowDetailView(seedShow: show)
                            } label: {
                                ShowRowView(show: show)
                            }
                        }
                    }
                }

                if !viewModel.visiblePopular.isEmpty {
                    Section("Popular") {
                        ForEach(viewModel.visiblePopular) { show in
                            NavigationLink {
                                ShowDetailView(seedShow: show)
                            } label: {
                                ShowRowView(show: show)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}
