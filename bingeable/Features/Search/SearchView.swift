import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.results.isEmpty {
                EmptyStateView(
                    title: "Search TV Shows",
                    message: "Find any show and check if it's ready to binge.",
                    systemImage: "magnifyingglass"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.results) { show in
                    NavigationLink {
                        ShowDetailView(seedShow: show)
                    } label: {
                        ShowRowView(show: show)
                    }
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search shows")
        .onSubmit(of: .search) {
            Task {
                await viewModel.search(using: appContainer.showRepository)
            }
        }
        .onChange(of: viewModel.query) {
            if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.results = []
                viewModel.errorMessage = nil
            }
        }
    }
}
